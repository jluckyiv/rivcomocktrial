// Per-tournament eligibility domain helpers. Pure functions over plain
// shapes — no PocketBase dependency.
//
// Enrollment (coach/team exists in the system) is tracked on the coach
// and team records directly. Eligibility (approved to compete in a
// specific tournament) is tracked in the tournaments_teams collection
// and modelled here.

import { USER_STATUS, type UserStatus } from './registration';

export { USER_STATUS } from './registration';

export const ELIGIBILITY_STATUS = {
	pending: 'pending',
	eligible: 'eligible',
	ineligible: 'ineligible',
	withdrawn: 'withdrawn'
} as const;

export type EligibilityStatus = (typeof ELIGIBILITY_STATUS)[keyof typeof ELIGIBILITY_STATUS];

// Maps a coach's enrollment approval to the team's eligibility status.
// Returns null when the coach status implies no transition (pending).
export function nextEligibilityForUserStatus(userStatus: UserStatus): EligibilityStatus | null {
	switch (userStatus) {
		case USER_STATUS.approved:
			return ELIGIBILITY_STATUS.eligible;
		case USER_STATUS.rejected:
			return ELIGIBILITY_STATUS.ineligible;
		case USER_STATUS.pending:
			return null;
	}
}

export function eligibleTeamCount(rows: ReadonlyArray<{ status: string }>): number {
	return rows.filter((r) => r.status === ELIGIBILITY_STATUS.eligible).length;
}

export type TournamentReadiness =
	| { ok: true; eligibleCount: number }
	| { ok: false; eligibleCount: number; reason: string };

export function canRunTournament(
	rows: ReadonlyArray<{ status: string }>
): TournamentReadiness {
	const eligibleCount = eligibleTeamCount(rows);
	if (eligibleCount === 0) {
		return { ok: false, eligibleCount, reason: 'No eligible teams yet.' };
	}
	if (eligibleCount % 2 !== 0) {
		return {
			ok: false,
			eligibleCount,
			reason: `Odd number of eligible teams (${eligibleCount}). Tournaments require an even number.`
		};
	}
	return { ok: true, eligibleCount };
}
