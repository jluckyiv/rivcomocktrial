import { describe, expect, test } from 'vitest';
import {
	activeTeamCount,
	canRunTournament,
	isTournamentOpenForRegistration,
	nextTeamStatusForUserStatus,
	TEAM_STATUS,
	TOURNAMENT_STATUS,
	USER_STATUS
} from './registration';

describe('isTournamentOpenForRegistration', () => {
	test('true when status is registration', () => {
		expect(isTournamentOpenForRegistration({ status: TOURNAMENT_STATUS.registration })).toBe(true);
	});

	test.each([TOURNAMENT_STATUS.draft, TOURNAMENT_STATUS.active, TOURNAMENT_STATUS.completed])(
		'false when status is %s',
		(status) => {
			expect(isTournamentOpenForRegistration({ status })).toBe(false);
		}
	);

	test('false when tournament is null or undefined', () => {
		expect(isTournamentOpenForRegistration(null)).toBe(false);
		expect(isTournamentOpenForRegistration(undefined)).toBe(false);
	});
});

describe('activeTeamCount', () => {
	test('counts only teams with active status', () => {
		const teams = [
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.pending },
			{ status: TEAM_STATUS.withdrawn },
			{ status: TEAM_STATUS.rejected }
		];
		expect(activeTeamCount(teams)).toBe(2);
	});

	test('returns 0 for empty list', () => {
		expect(activeTeamCount([])).toBe(0);
	});
});

describe('canRunTournament', () => {
	test('not ok when there are no active teams', () => {
		const result = canRunTournament([]);
		expect(result).toEqual({ ok: false, activeCount: 0, reason: expect.any(String) });
	});

	test('not ok when active team count is odd', () => {
		const teams = [
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active }
		];
		const result = canRunTournament(teams);
		expect(result.ok).toBe(false);
		expect(result.activeCount).toBe(3);
		if (!result.ok) {
			expect(result.reason).toMatch(/odd/i);
		}
	});

	test('ok when active team count is even and non-zero', () => {
		const teams = [
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active }
		];
		expect(canRunTournament(teams)).toEqual({ ok: true, activeCount: 4 });
	});

	test('ignores non-active teams when checking parity', () => {
		const teams = [
			{ status: TEAM_STATUS.active },
			{ status: TEAM_STATUS.active },
			// Three non-active teams should be ignored — active count is even.
			{ status: TEAM_STATUS.pending },
			{ status: TEAM_STATUS.withdrawn },
			{ status: TEAM_STATUS.rejected }
		];
		expect(canRunTournament(teams)).toEqual({ ok: true, activeCount: 2 });
	});
});

describe('nextTeamStatusForUserStatus', () => {
	test('approved coach → active team', () => {
		expect(nextTeamStatusForUserStatus(USER_STATUS.approved)).toBe(TEAM_STATUS.active);
	});

	test('rejected coach → rejected team', () => {
		expect(nextTeamStatusForUserStatus(USER_STATUS.rejected)).toBe(TEAM_STATUS.rejected);
	});

	test('pending coach → no team transition', () => {
		expect(nextTeamStatusForUserStatus(USER_STATUS.pending)).toBeNull();
	});
});
