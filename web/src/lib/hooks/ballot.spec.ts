/**
 * Hook integration tests for ballot_guard.pb.js.
 *
 * Covers onRecordCreateRequest + onRecordAfterCreateSuccess on
 * ballot_submissions and presider_ballots:
 *
 * ballot_submissions:
 *   valid scorer token → submission created (201), token used = true
 *   scorer token submitted to presider endpoint → 400 wrong role
 *   scorer token submitted twice → 400 already used
 *
 * presider_ballots:
 *   valid presider token → ballot created (201), token used = true
 *   presider token submitted to scorer endpoint → 400 wrong role
 *
 * Run: `npm run test:hooks` from repo root.
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pbCreate, pbDelete, pbList, PbError } from '../test-helpers/pb-admin';

type Tracked = { collection: string; id: string };

const tracked: Tracked[] = [];

let trialId: string;
let scorerTokenId: string;
let presiderTokenId: string;

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

// Cleanup in dependency order:
// ballots → tokens → trials → rounds/courtrooms → teams → tournaments
const CLEANUP_ORDER = [
	'ballot_submissions',
	'presider_ballots',
	'scorer_tokens',
	'trials',
	'rounds',
	'courtrooms',
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

async function freshScorerToken(role: 'scorer' | 'presider'): Promise<string> {
	const token = await pbCreate('scorer_tokens', {
		token: `test-token-${role}-${RUN_ID}-${Date.now()}`,
		scorer_role: role,
		scorer_name: `Test ${role}`,
		status: 'active',
		trial: trialId
	});
	const id = (token as { id: string }).id;
	track('scorer_tokens', id);
	return id;
}

beforeAll(async () => {
	const schools = await pbList('schools', '');
	if (schools.length === 0) throw new Error('No schools — run npm run pb:test:up from repo root.');
	const schoolId = (schools[0] as { id: string }).id;

	// Tournament — non-registration status avoids interfering with the
	// registration hook running in parallel spec files.
	const tournament = await pbCreate('tournaments', {
		name: `hooks-ballot-tournament-${RUN_ID}`,
		year: 2099,
		num_preliminary_rounds: 3,
		num_elimination_rounds: 2,
		status: 'active'
	});
	const tournamentId = (tournament as { id: string }).id;
	track('tournaments', tournamentId);

	// Two teams — ballot guard only needs them as relations on the trial.
	const prosecution = await pbCreate('teams', {
		name: `hooks-ballot-prosecution-${RUN_ID}`,
		school: schoolId,
		tournament: tournamentId,
		status: 'active'
	});
	const prosecutionId = (prosecution as { id: string }).id;
	track('teams', prosecutionId);

	const defense = await pbCreate('teams', {
		name: `hooks-ballot-defense-${RUN_ID}`,
		school: schoolId,
		tournament: tournamentId,
		status: 'active'
	});
	const defenseId = (defense as { id: string }).id;
	track('teams', defenseId);

	const round = await pbCreate('rounds', {
		tournament: tournamentId,
		number: 1,
		type: 'preliminary',
		status: 'open'
	});
	const roundId = (round as { id: string }).id;
	track('rounds', roundId);

	const courtroom = await pbCreate('courtrooms', {
		name: `hooks-ballot-courtroom-${RUN_ID}`
	});
	const courtroomId = (courtroom as { id: string }).id;
	track('courtrooms', courtroomId);

	const trial = await pbCreate('trials', {
		round: roundId,
		courtroom: courtroomId,
		prosecution_team: prosecutionId,
		defense_team: defenseId
	});
	trialId = (trial as { id: string }).id;
	track('trials', trialId);

	// Scorer and presider tokens for the happy-path tests.
	scorerTokenId = await freshScorerToken('scorer');
	presiderTokenId = await freshScorerToken('presider');
});

afterAll(cleanup);

describe('ballot_submissions', () => {
	it('valid scorer token creates submission and marks token used', async () => {
		const submission = await pbCreate('ballot_submissions', {
			trial: trialId,
			scorer_token: scorerTokenId,
			status: 'submitted',
			submitted_at: new Date().toISOString()
		});
		const submissionId = (submission as { id: string }).id;
		track('ballot_submissions', submissionId);

		const tokens = await pbList('scorer_tokens', `id = '${scorerTokenId}'`);
		expect((tokens[0] as { status: string }).status).toBe('used');
	});

	it('scorer token submitted to presider endpoint returns 400 wrong role', async () => {
		const wrongRoleScorerTokenId = await freshScorerToken('scorer');

		const err = await pbCreate('presider_ballots', {
			trial: trialId,
			scorer_token: wrongRoleScorerTokenId,
			submitted_at: new Date().toISOString(),
			winner_side: 'prosecution'
		}).catch((e: unknown) => e);

		expect(err).toBeInstanceOf(PbError);
		expect((err as PbError).status).toBe(400);
	});

	it('scorer token submitted twice returns 400 already used', async () => {
		const doubleTokenId = await freshScorerToken('scorer');

		// First submission — should succeed.
		const first = await pbCreate('ballot_submissions', {
			trial: trialId,
			scorer_token: doubleTokenId,
			status: 'submitted',
			submitted_at: new Date().toISOString()
		});
		track('ballot_submissions', (first as { id: string }).id);

		// Second submission with the same token — should fail.
		const err = await pbCreate('ballot_submissions', {
			trial: trialId,
			scorer_token: doubleTokenId,
			status: 'submitted',
			submitted_at: new Date().toISOString()
		}).catch((e: unknown) => e);

		expect(err).toBeInstanceOf(PbError);
		expect((err as PbError).status).toBe(400);
	});
});

describe('presider_ballots', () => {
	it('valid presider token creates ballot and marks token used', async () => {
		const ballot = await pbCreate('presider_ballots', {
			trial: trialId,
			scorer_token: presiderTokenId,
			submitted_at: new Date().toISOString(),
			winner_side: 'prosecution'
		});
		const ballotId = (ballot as { id: string }).id;
		track('presider_ballots', ballotId);

		const tokens = await pbList('scorer_tokens', `id = '${presiderTokenId}'`);
		expect((tokens[0] as { status: string }).status).toBe('used');
	});

	it('presider token submitted to scorer endpoint returns 400 wrong role', async () => {
		const wrongRolePresiderTokenId = await freshScorerToken('presider');

		const err = await pbCreate('ballot_submissions', {
			trial: trialId,
			scorer_token: wrongRolePresiderTokenId,
			status: 'submitted',
			submitted_at: new Date().toISOString()
		}).catch((e: unknown) => e);

		expect(err).toBeInstanceOf(PbError);
		expect((err as PbError).status).toBe(400);
	});
});
