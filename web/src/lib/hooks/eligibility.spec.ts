/**
 * Hook integration tests for eligibility.pb.js.
 *
 * Covers onRecordAfterUpdateSuccess on "eligibility_change_requests":
 *   approve "add" request → new eligibility_list_entries row created
 *   approve "remove" request → matching active entry flipped to "removed"
 *   update to non-approved status → no entry created or changed
 *
 * Run: `npm run test:hooks` from repo root.
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pbCreate, pbDelete, pbList, pbPatch, PbError } from '../test-helpers/pb-admin';

type Tracked = { collection: string; id: string };

let teamTournamentId: string;
let teamId: string;
let schoolId: string;

const tracked: Tracked[] = [];

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

const CLEANUP_ORDER = [
	'eligibility_list_entries',
	'eligibility_change_requests',
	'teams',
	'tournaments'
] as const;

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

	// Use a non-registration status so the registration hook in other parallel
	// spec files does not pick up this tournament (it only looks for 'registration').
	const tournament = await pbCreate('tournaments', {
		name: `hooks-elig-tournament-${RUN_ID}`,
		year: 2099,
		num_preliminary_rounds: 3,
		num_elimination_rounds: 2,
		status: 'active'
	});
	teamTournamentId = (tournament as { id: string }).id;
	track('tournaments', teamTournamentId);

	// Create the team directly via the admin API rather than the registration
	// hook. The eligibility hook only needs a team that exists with a tournament;
	// it does not care how the team was created.
	const team = await pbCreate('teams', {
		name: `hooks-elig-team-${RUN_ID}`,
		school: schoolId,
		tournament: teamTournamentId,
		status: 'active'
	});
	teamId = (team as { id: string }).id;
	track('teams', teamId);
});

afterAll(cleanup);

describe('eligibility_change_requests', () => {
	it('approve "add" request creates a new active eligibility_list_entries row', async () => {
		const req = await pbCreate('eligibility_change_requests', {
			team: teamId,
			student_name: `Student-Add-${RUN_ID}`,
			change_type: 'add',
			status: 'pending'
		});
		const reqId = (req as { id: string }).id;
		track('eligibility_change_requests', reqId);

		await pbPatch('eligibility_change_requests', reqId, { status: 'approved' });

		const entries = await pbList(
			'eligibility_list_entries',
			`team = '${teamId}' && name = 'Student-Add-${RUN_ID}' && status = 'active'`
		);
		expect(entries).toHaveLength(1);
		const entry = entries[0] as { id: string; tournament: string; status: string };
		track('eligibility_list_entries', entry.id);
		expect(entry.tournament).toBe(teamTournamentId);
		expect(entry.status).toBe('active');
	});

	it('approve "remove" request flips matching active entry to "removed"', async () => {
		// Seed an active entry directly.
		const entry = await pbCreate('eligibility_list_entries', {
			team: teamId,
			tournament: teamTournamentId,
			name: `Student-Remove-${RUN_ID}`,
			status: 'active'
		});
		const entryId = (entry as { id: string }).id;
		track('eligibility_list_entries', entryId);

		const req = await pbCreate('eligibility_change_requests', {
			team: teamId,
			student_name: `Student-Remove-${RUN_ID}`,
			change_type: 'remove',
			status: 'pending'
		});
		const reqId = (req as { id: string }).id;
		track('eligibility_change_requests', reqId);

		await pbPatch('eligibility_change_requests', reqId, { status: 'approved' });

		const updated = await pbList('eligibility_list_entries', `id = '${entryId}'`);
		expect((updated[0] as { status: string }).status).toBe('removed');
	});

	it('update to non-approved status does not create or change entries', async () => {
		const entriesBefore = await pbList(
			'eligibility_list_entries',
			`team = '${teamId}' && name = 'Student-Reject-${RUN_ID}'`
		);
		expect(entriesBefore).toHaveLength(0);

		const req = await pbCreate('eligibility_change_requests', {
			team: teamId,
			student_name: `Student-Reject-${RUN_ID}`,
			change_type: 'add',
			status: 'pending'
		});
		const reqId = (req as { id: string }).id;
		track('eligibility_change_requests', reqId);

		await pbPatch('eligibility_change_requests', reqId, { status: 'rejected' });

		const entriesAfter = await pbList(
			'eligibility_list_entries',
			`team = '${teamId}' && name = 'Student-Reject-${RUN_ID}'`
		);
		expect(entriesAfter).toHaveLength(0);
	});
});
