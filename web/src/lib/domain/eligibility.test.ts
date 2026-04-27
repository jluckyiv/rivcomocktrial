import { describe, expect, test } from 'vitest';
import {
	canRunTournament,
	ELIGIBILITY_STATUS,
	eligibleTeamCount,
	nextEligibilityForUserStatus,
	USER_STATUS
} from './eligibility';

describe('nextEligibilityForUserStatus', () => {
	test('approved coach → eligible', () => {
		expect(nextEligibilityForUserStatus(USER_STATUS.approved)).toBe(ELIGIBILITY_STATUS.eligible);
	});

	test('rejected coach → ineligible', () => {
		expect(nextEligibilityForUserStatus(USER_STATUS.rejected)).toBe(ELIGIBILITY_STATUS.ineligible);
	});

	test('pending coach → no transition', () => {
		expect(nextEligibilityForUserStatus(USER_STATUS.pending)).toBeNull();
	});
});

describe('eligibleTeamCount', () => {
	test('counts only eligible rows', () => {
		const rows = [
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.pending },
			{ status: ELIGIBILITY_STATUS.ineligible },
			{ status: ELIGIBILITY_STATUS.withdrawn }
		];
		expect(eligibleTeamCount(rows)).toBe(2);
	});

	test('returns 0 for empty list', () => {
		expect(eligibleTeamCount([])).toBe(0);
	});
});

describe('canRunTournament', () => {
	test('not ok when there are no eligible teams', () => {
		const result = canRunTournament([]);
		expect(result).toEqual({ ok: false, eligibleCount: 0, reason: expect.any(String) });
	});

	test('not ok when eligible team count is odd', () => {
		const rows = [
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible }
		];
		const result = canRunTournament(rows);
		expect(result.ok).toBe(false);
		expect(result.eligibleCount).toBe(3);
		if (!result.ok) {
			expect(result.reason).toMatch(/odd/i);
		}
	});

	test('ok when eligible team count is even and non-zero', () => {
		const rows = [
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible }
		];
		expect(canRunTournament(rows)).toEqual({ ok: true, eligibleCount: 4 });
	});

	test('ignores non-eligible rows when checking parity', () => {
		const rows = [
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.eligible },
			{ status: ELIGIBILITY_STATUS.pending },
			{ status: ELIGIBILITY_STATUS.ineligible },
			{ status: ELIGIBILITY_STATUS.withdrawn }
		];
		expect(canRunTournament(rows)).toEqual({ ok: true, eligibleCount: 2 });
	});
});
