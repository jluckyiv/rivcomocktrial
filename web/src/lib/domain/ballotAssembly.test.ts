import { describe, expect, test } from 'vitest';
import {
	type BallotCorrection,
	type BallotScore,
	type PresentationKind,
	type PresiderBallotRecord,
	type RosterSide,
	assemblePresiderBallot,
	assembleScoredPresentation,
	assembleSubmittedBallot,
	assembleVerifiedBallot
} from './ballotAssembly';

let scoreId = 0;
function fakeScore(
	presentation: PresentationKind,
	side: RosterSide,
	studentName: string,
	points: number,
	overrides: Partial<BallotScore> = {}
): BallotScore {
	return {
		id: `score-${++scoreId}`,
		ballot: 'ballot1',
		presentation,
		side,
		studentName,
		rosterEntry: null,
		points,
		sortOrder: 0,
		created: '2026-01-01',
		updated: '2026-01-01',
		...overrides
	};
}

function fakePresiderRecord(side: RosterSide): PresiderBallotRecord {
	return {
		id: 'presider1',
		scorerToken: 'token1',
		trial: 'trial1',
		winnerSide: side,
		motionRuling: null,
		verdict: null,
		submittedAt: '2026-01-01',
		created: '2026-01-01',
		updated: '2026-01-01'
	};
}

const s1 = fakeScore('Pretrial', 'Prosecution', 'Alice Smith', 7, { id: 'score-1', sortOrder: 1 });
const s2 = fakeScore('Opening', 'Prosecution', 'Alice Smith', 8, { id: 'score-2', sortOrder: 2 });
const s3 = fakeScore('Closing', 'Defense', 'Bob Jones', 9, { id: 'score-3', sortOrder: 3 });
const simpleBallotScores: BallotScore[] = [s1, s2, s3];

describe('BallotAssembly', () => {
	describe('assembleStudent (via assembleScoredPresentation)', () => {
		test('parses first and last name', () => {
			const result = assembleScoredPresentation(
				fakeScore('Pretrial', 'Prosecution', 'Alice Smith', 7)
			);
			expect(result.ok).toBe(true);
		});

		test('handles compound first name', () => {
			const result = assembleScoredPresentation(
				fakeScore('Pretrial', 'Prosecution', 'Mary Jane Smith', 7)
			);
			expect(result.ok).toBe(true);
			if (result.ok) {
				expect(result.value.firstName).toBe('Mary Jane');
				expect(result.value.lastName).toBe('Smith');
			}
		});

		test('handles single-word name (no space)', () => {
			const result = assembleScoredPresentation(fakeScore('Pretrial', 'Prosecution', 'Madonna', 7));
			expect(result.ok).toBe(true);
		});
	});

	describe('assembleScoredPresentation', () => {
		test('Pretrial maps to Double weight', () => {
			const result = assembleScoredPresentation(
				fakeScore('Pretrial', 'Prosecution', 'Alice Smith', 7)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Double');
		});

		test('Opening maps to Single weight', () => {
			const result = assembleScoredPresentation(
				fakeScore('Opening', 'Prosecution', 'Alice Smith', 8)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Single');
		});

		test('Closing maps to Double weight', () => {
			const result = assembleScoredPresentation(fakeScore('Closing', 'Defense', 'Bob Jones', 9));
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Double');
		});

		test('DirectExamination is Single weight', () => {
			const result = assembleScoredPresentation(
				fakeScore('DirectExamination', 'Prosecution', 'Alice Smith', 6)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Single');
		});

		test('CrossExamination is Single weight', () => {
			const result = assembleScoredPresentation(
				fakeScore('CrossExamination', 'Defense', 'Bob Jones', 5)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Single');
		});

		test('WitnessExamination is Single weight', () => {
			const result = assembleScoredPresentation(
				fakeScore('WitnessExamination', 'Prosecution', 'Alice Smith', 7)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.weight).toBe('Single');
		});

		test('ClerkPerformance ignores api side — hard-codes Prosecution', () => {
			const result = assembleScoredPresentation(
				fakeScore('ClerkPerformance', 'Defense', 'Alice Smith', 7)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.side).toBe('Prosecution');
		});

		test('BailiffPerformance ignores api side — hard-codes Defense', () => {
			const result = assembleScoredPresentation(
				fakeScore('BailiffPerformance', 'Prosecution', 'Bob Jones', 7)
			);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.side).toBe('Defense');
		});

		test('side is preserved for scored presentations', () => {
			const result = assembleScoredPresentation(fakeScore('Opening', 'Defense', 'Bob Jones', 8));
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.side).toBe('Defense');
		});

		test('points above range (11) returns error', () => {
			const result = assembleScoredPresentation(
				fakeScore('Opening', 'Prosecution', 'Alice Smith', 11)
			);
			expect(result.ok).toBe(false);
		});

		test('points below range (0) returns error', () => {
			const result = assembleScoredPresentation(
				fakeScore('Opening', 'Prosecution', 'Alice Smith', 0)
			);
			expect(result.ok).toBe(false);
		});

		test('points at minimum (1) succeeds', () => {
			const result = assembleScoredPresentation(
				fakeScore('Opening', 'Prosecution', 'Alice Smith', 1)
			);
			expect(result.ok).toBe(true);
		});

		test('points at maximum (10) succeeds', () => {
			const result = assembleScoredPresentation(
				fakeScore('Opening', 'Prosecution', 'Alice Smith', 10)
			);
			expect(result.ok).toBe(true);
		});
	});

	describe('assembleSubmittedBallot', () => {
		test('empty list fails', () => {
			expect(assembleSubmittedBallot([]).ok).toBe(false);
		});

		test('valid list succeeds', () => {
			expect(assembleSubmittedBallot(simpleBallotScores).ok).toBe(true);
		});

		test('scores sorted by sortOrder', () => {
			const closing = fakeScore('Closing', 'Defense', 'Bob Jones', 9, { sortOrder: 2 });
			const pretrial = fakeScore('Pretrial', 'Prosecution', 'Alice Smith', 7, { sortOrder: 1 });
			const result = assembleSubmittedBallot([closing, pretrial]);
			expect(result.ok).toBe(true);
			if (result.ok) {
				expect(result.value.presentations.map((p) => p.weight)).toEqual(['Double', 'Double']);
			}
		});

		test('invalid points in any score fails the whole ballot', () => {
			const badScore = fakeScore('Opening', 'Prosecution', 'Alice Smith', 11, { sortOrder: 2 });
			const result = assembleSubmittedBallot([
				fakeScore('Pretrial', 'Prosecution', 'Alice Smith', 7, { sortOrder: 1 }),
				badScore
			]);
			expect(result.ok).toBe(false);
		});
	});

	describe('assembleVerifiedBallot', () => {
		test('no corrections: presentations match original', () => {
			const ballotResult = assembleSubmittedBallot(simpleBallotScores);
			expect(ballotResult.ok).toBe(true);
			if (!ballotResult.ok) return;
			const verifiedResult = assembleVerifiedBallot(ballotResult.value, simpleBallotScores, []);
			expect(verifiedResult.ok).toBe(true);
			if (verifiedResult.ok) {
				expect(verifiedResult.value.presentations).toEqual(ballotResult.value.presentations);
			}
		});

		test('with correction: corrected points replace original', () => {
			const ballotResult = assembleSubmittedBallot(simpleBallotScores);
			expect(ballotResult.ok).toBe(true);
			if (!ballotResult.ok) return;
			const correction: BallotCorrection = {
				id: 'corr1',
				ballot: 'ballot1',
				originalScoreId: s1.id,
				correctedPoints: 3,
				reason: 'Entry error',
				correctedAt: '2026-01-01',
				created: '2026-01-01',
				updated: '2026-01-01'
			};
			const verifiedResult = assembleVerifiedBallot(ballotResult.value, simpleBallotScores, [
				correction
			]);
			expect(verifiedResult.ok).toBe(true);
			if (verifiedResult.ok) {
				expect(verifiedResult.value.presentations[0]?.points).toBe(3);
			}
		});

		test('original is preserved under corrections', () => {
			const ballotResult = assembleSubmittedBallot(simpleBallotScores);
			expect(ballotResult.ok).toBe(true);
			if (!ballotResult.ok) return;
			const correction: BallotCorrection = {
				id: 'corr1',
				ballot: 'ballot1',
				originalScoreId: s1.id,
				correctedPoints: 3,
				reason: null,
				correctedAt: '2026-01-01',
				created: '2026-01-01',
				updated: '2026-01-01'
			};
			const verifiedResult = assembleVerifiedBallot(ballotResult.value, simpleBallotScores, [
				correction
			]);
			expect(verifiedResult.ok).toBe(true);
			if (verifiedResult.ok) {
				expect(verifiedResult.value.original.presentations).toEqual(
					ballotResult.value.presentations
				);
			}
		});
	});

	describe('assemblePresiderBallot', () => {
		test('Prosecution winner_side maps to Prosecution', () => {
			expect(assemblePresiderBallot(fakePresiderRecord('Prosecution')).winner).toBe('Prosecution');
		});

		test('Defense winner_side maps to Defense', () => {
			expect(assemblePresiderBallot(fakePresiderRecord('Defense')).winner).toBe('Defense');
		});
	});
});
