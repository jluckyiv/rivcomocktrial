/**
 * Hook integration tests for registration.pb.js.
 *
 * Covers all four callbacks:
 *   onRecordCreateRequest  — pre-commit validation + join-intent stash
 *   onRecordAfterCreateSuccess — new-team vs join-existing post-commit
 *   onRecordDeleteRequest  — sole-coach guard
 *   onRecordAfterUpdateSuccess — status sync (approved → active, rejected → rejected)
 *
 * Run: `npm run test:hooks` from repo root. The script starts the
 * isolated test PocketBase (docker-compose.test.yml) on port 28090
 * and sources .env.test for credentials.
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pbCreate, pbDelete, pbList, pbPatch, PbError } from '../test-helpers/pb-admin';

type Tracked = { collection: string; id: string };

let schoolId: string;
const tracked: Tracked[] = [];

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

function untrack(collection: string, id: string) {
	const i = tracked.findIndex((t) => t.collection === collection && t.id === id);
	if (i !== -1) tracked.splice(i, 1);
}

// Cleanup deletes by collection-class in dependency order rather than
// LIFO insertion order. The sole-coach delete guard (registration.pb.js)
// fires when a user delete leaves a team with no coaches, so all
// dependent records must be gone before any user is deleted.
const CLEANUP_ORDER = ['join_requests', 'teams', 'users', 'tournaments'] as const;

async function cleanup() {
	const failures: string[] = [];
	for (const collection of CLEANUP_ORDER) {
		const ids = tracked.filter((t) => t.collection === collection).map((t) => t.id);
		for (const id of ids) {
			try {
				await pbDelete(collection, id);
			} catch (err) {
				const detail =
					err instanceof PbError ? `${err.status} ${JSON.stringify(err.data)}` : String(err);
				failures.push(`${collection}/${id}: ${detail}`);
			}
		}
	}
	tracked.length = 0;
	if (failures.length > 0) {
		throw new Error(
			`Cleanup left orphan records (${failures.length}). ` +
				`Hook tests must fully tear down state. Failures:\n  - ${failures.join('\n  - ')}`
		);
	}
}

beforeAll(async () => {
	const tournament = await pbCreate('tournaments', {
		name: 'hooks-reg-tournament',
		year: 2099,
		num_preliminary_rounds: 3,
		num_elimination_rounds: 2,
		status: 'registration'
	});
	track('tournaments', (tournament as { id: string }).id);

	// Schools are seeded by migration — pick any existing one.
	const schools = await pbList('schools', '');
	if (schools.length === 0) throw new Error('No schools — run npm run pb:start from repo root.');
	schoolId = (schools[0] as { id: string }).id;
});

afterAll(cleanup);

// RUN_ID makes emails and team names unique per test run so leftover
// records from a failed cleanup never trip the unique index.
const RUN_ID = Date.now().toString(36);

function coachBody(suffix: string, teamName: string, extra?: Record<string, unknown>) {
	return {
		email: `hooks-reg-${suffix}-${RUN_ID}@test.invalid`,
		password: 'testpass123',
		passwordConfirm: 'testpass123',
		name: `hooks-reg-${suffix}-${RUN_ID}`,
		role: 'coach',
		status: 'pending',
		school: schoolId,
		team_name: `${teamName}-${RUN_ID}`,
		...extra
	};
}

describe('new-team path', () => {
	it('creates a pending team linked to the coach', async () => {
		const coach = await pbCreate('users', coachBody('new-team', 'hooks-reg-new-team'));
		const coachId = (coach as { id: string }).id;
		track('users', coachId);

		const teams = await pbList('teams', `coaches ~ '${coachId}'`);
		expect(teams).toHaveLength(1);
		const team = teams[0] as { id: string; coaches: string[]; status: string };
		track('teams', team.id);

		expect(team.coaches).toContain(coachId);
		expect(team.status).toBe('pending');
	});
});

describe('join-existing path', () => {
	it('creates a join_requests row and no duplicate team', async () => {
		const coachA = await pbCreate('users', coachBody('join-a', 'hooks-reg-join-team'));
		const coachAId = (coachA as { id: string }).id;
		track('users', coachAId);

		const teams = await pbList('teams', `coaches ~ '${coachAId}'`);
		expect(teams).toHaveLength(1);
		const teamA = teams[0] as { id: string; name: string };
		track('teams', teamA.id);

		// Override team_name with the exact existing name — no RUN_ID suffix.
		const coachB = await pbCreate(
			'users',
			coachBody('join-b', '', { team_name: teamA.name, join_team_id: teamA.id })
		);
		const coachBId = (coachB as { id: string }).id;
		track('users', coachBId);

		const joinRequests = await pbList(
			'join_requests',
			`user = '${coachBId}' && team = '${teamA.id}'`
		);
		expect(joinRequests).toHaveLength(1);
		const jr = joinRequests[0] as { id: string; status: string };
		track('join_requests', jr.id);
		expect(jr.status).toBe('pending');

		const allTeams = await pbList('teams', `coaches ~ '${coachAId}'`);
		expect(allTeams).toHaveLength(1);
	});
});

describe('collision-without-intent', () => {
	it('returns 400 with existingTeamId when name+school collide and no join_team_id', async () => {
		const coachA = await pbCreate('users', coachBody('col-a', 'hooks-reg-col-team'));
		const coachAId = (coachA as { id: string }).id;
		track('users', coachAId);

		const teams = await pbList('teams', `coaches ~ '${coachAId}'`);
		const team = teams[0] as { id: string };
		track('teams', team.id);

		const colTeam = (await pbList('teams', `coaches ~ '${coachAId}'`))[0] as { name: string };
		const err = await pbCreate('users', coachBody('col-b', '', { team_name: colTeam.name })).catch(
			(e: unknown) => e
		);

		expect(err).toBeInstanceOf(PbError);
		const pbErr = err as PbError;
		expect(pbErr.status).toBe(400);
		// PocketBase normalizes BadRequestError data values into validation error
		// objects, so the raw team ID is not preserved. Assert the key is present.
		expect((pbErr.data as { data?: Record<string, unknown> }).data).toHaveProperty(
			'existingTeamId'
		);
	});
});

describe('sole-coach delete guard', () => {
	it('blocks deletion of the sole coach on a pending team with 400', async () => {
		const coach = await pbCreate('users', coachBody('del-sole', 'hooks-reg-del-sole-team'));
		const coachId = (coach as { id: string }).id;
		track('users', coachId);

		const teams = await pbList('teams', `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track('teams', team.id);

		const err = await pbDelete('users', coachId).catch((e: unknown) => e);
		expect(err).toBeInstanceOf(PbError);
		expect((err as PbError).status).toBe(400);
	});
});

describe('two-coach delete allowed', () => {
	it('allows deleting one coach when another remains on the team', async () => {
		const coachA = await pbCreate('users', coachBody('del-two-a', 'hooks-reg-del-two-team'));
		const coachAId = (coachA as { id: string }).id;
		track('users', coachAId);

		const teams = await pbList('teams', `coaches ~ '${coachAId}'`);
		const team = teams[0] as { id: string; coaches: string[] };
		track('teams', team.id);

		const coachB = await pbCreate('users', coachBody('del-two-b', 'hooks-reg-del-two-team-b'));
		const coachBId = (coachB as { id: string }).id;
		track('users', coachBId);

		// Track coach B's own team so cleanup can delete it.
		const coachBTeams = await pbList('teams', `coaches ~ '${coachBId}'`);
		if (coachBTeams.length > 0) track('teams', (coachBTeams[0] as { id: string }).id);

		// Add coach B to coach A's team directly via admin PATCH.
		await pbPatch('teams', team.id, { coaches: [coachAId, coachBId] });

		// Deleting coach A should succeed now that coach B is on the team.
		await pbDelete('users', coachAId);
		untrack('users', coachAId);

		// Confirm coach A is gone and coach B remains on the team.
		const remaining = await pbList('teams', `id = '${team.id}'`);
		expect((remaining[0] as { coaches: string[] }).coaches).not.toContain(coachAId);
		expect((remaining[0] as { coaches: string[] }).coaches).toContain(coachBId);
	});
});

describe('status sync', () => {
	it('promotes team to active when coach is approved', async () => {
		const coach = await pbCreate('users', coachBody('sync-approve', 'hooks-reg-sync-approve'));
		const coachId = (coach as { id: string }).id;
		track('users', coachId);

		const teams = await pbList('teams', `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track('teams', team.id);

		await pbPatch('users', coachId, { status: 'approved' });

		const updated = await pbList('teams', `id = '${team.id}'`);
		expect((updated[0] as { status: string }).status).toBe('active');
	});

	it('rejects team when coach is rejected', async () => {
		const coach = await pbCreate('users', coachBody('sync-reject', 'hooks-reg-sync-reject'));
		const coachId = (coach as { id: string }).id;
		track('users', coachId);

		const teams = await pbList('teams', `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track('teams', team.id);

		await pbPatch('users', coachId, { status: 'rejected' });

		const updated = await pbList('teams', `id = '${team.id}'`);
		expect((updated[0] as { status: string }).status).toBe('rejected');
	});
});
