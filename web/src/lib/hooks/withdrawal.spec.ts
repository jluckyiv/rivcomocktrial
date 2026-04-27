/**
 * Hook integration tests for withdrawal.pb.js.
 *
 * Covers onRecordAfterUpdateSuccess on "withdrawal_requests":
 *   approve withdrawal request → tournaments_teams.status becomes "withdrawn"
 *   update to non-approved status → tournaments_teams.status unchanged
 *
 * Run: `npm run test:hooks` from repo root.
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pbCreate, pbDelete, pbList, pbPatch, PbError } from '../test-helpers/pb-admin';

type Tracked = { collection: string; id: string };

let tournamentId: string;
let schoolId: string;

const tracked: Tracked[] = [];

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

const CLEANUP_ORDER = ['withdrawal_requests', 'tournaments_teams', 'teams', 'tournaments'] as const;

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

const RUN_ID = Date.now().toString(36);

beforeAll(async () => {
	const schools = await pbList('schools', '');
	if (schools.length === 0) throw new Error('No schools — run npm run pb:test:up from repo root.');
	schoolId = (schools[0] as { id: string }).id;

	// Use a non-registration status to avoid interfering with the registration
	// hook in parallel spec files (which only looks for 'registration' tournaments).
	const tournament = await pbCreate('tournaments', {
		name: `hooks-withdrawal-tournament-${RUN_ID}`,
		year: 2099,
		num_preliminary_rounds: 3,
		num_elimination_rounds: 2,
		status: 'active'
	});
	tournamentId = (tournament as { id: string }).id;
	track('tournaments', tournamentId);
});

afterAll(cleanup);

describe('withdrawal_requests', () => {
	it('approve withdrawal request sets tournaments_teams.status to "withdrawn"', async () => {
		const team = await pbCreate('teams', {
			name: `hooks-withdrawal-team-approve-${RUN_ID}`,
			school: schoolId,
			tournament: tournamentId
		});
		const teamId = (team as { id: string }).id;
		track('teams', teamId);

		const ttRow = await pbCreate('tournaments_teams', {
			team: teamId,
			tournament: tournamentId,
			status: 'eligible'
		});
		const ttRowId = (ttRow as { id: string }).id;
		track('tournaments_teams', ttRowId);

		const req = await pbCreate('withdrawal_requests', {
			team: teamId,
			status: 'pending'
		});
		const reqId = (req as { id: string }).id;
		track('withdrawal_requests', reqId);

		await pbPatch('withdrawal_requests', reqId, { status: 'approved' });

		const updated = await pbList('tournaments_teams', `id = '${ttRowId}'`);
		expect((updated[0] as { status: string }).status).toBe('withdrawn');
	});

	it('non-approved update does not change tournaments_teams.status', async () => {
		const team = await pbCreate('teams', {
			name: `hooks-withdrawal-team-reject-${RUN_ID}`,
			school: schoolId,
			tournament: tournamentId
		});
		const teamId = (team as { id: string }).id;
		track('teams', teamId);

		const ttRow = await pbCreate('tournaments_teams', {
			team: teamId,
			tournament: tournamentId,
			status: 'eligible'
		});
		const ttRowId = (ttRow as { id: string }).id;
		track('tournaments_teams', ttRowId);

		const req = await pbCreate('withdrawal_requests', {
			team: teamId,
			status: 'pending'
		});
		const reqId = (req as { id: string }).id;
		track('withdrawal_requests', reqId);

		await pbPatch('withdrawal_requests', reqId, { status: 'rejected' });

		const updated = await pbList('tournaments_teams', `id = '${ttRowId}'`);
		expect((updated[0] as { status: string }).status).toBe('eligible');
	});
});
