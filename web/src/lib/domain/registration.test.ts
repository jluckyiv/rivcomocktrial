import { describe, expect, test } from 'vitest';
import { isTournamentOpenForRegistration, TOURNAMENT_STATUS } from './registration';

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
