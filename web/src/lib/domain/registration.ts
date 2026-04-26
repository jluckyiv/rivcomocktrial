// Domain helpers for the registration / team-state machine. Pure
// functions over plain shapes so they can be unit-tested without
// any PocketBase fixtures.

export const TOURNAMENT_STATUS = {
	draft: 'draft',
	registration: 'registration',
	active: 'active',
	completed: 'completed'
} as const;

export type TournamentStatus = (typeof TOURNAMENT_STATUS)[keyof typeof TOURNAMENT_STATUS];

export const TEAM_STATUS = {
	pending: 'pending',
	active: 'active',
	withdrawn: 'withdrawn',
	rejected: 'rejected'
} as const;

export type TeamStatus = (typeof TEAM_STATUS)[keyof typeof TEAM_STATUS];

export const USER_STATUS = {
	pending: 'pending',
	approved: 'approved',
	rejected: 'rejected'
} as const;

export type UserStatus = (typeof USER_STATUS)[keyof typeof USER_STATUS];

export function isTournamentOpenForRegistration(
	t: { status: string } | null | undefined
): boolean {
	return t?.status === TOURNAMENT_STATUS.registration;
}

export function activeTeamCount(teams: ReadonlyArray<{ status: string }>): number {
	return teams.filter((t) => t.status === TEAM_STATUS.active).length;
}

export type TournamentReadiness =
	| { ok: true; activeCount: number }
	| { ok: false; activeCount: number; reason: string };

export function canRunTournament(teams: ReadonlyArray<{ status: string }>): TournamentReadiness {
	const activeCount = activeTeamCount(teams);
	if (activeCount === 0) {
		return { ok: false, activeCount, reason: 'No active teams yet.' };
	}
	if (activeCount % 2 !== 0) {
		return {
			ok: false,
			activeCount,
			reason: `Odd number of active teams (${activeCount}). Tournaments require an even number.`
		};
	}
	return { ok: true, activeCount };
}

// Registration state transitions. The hook in `registration.pb.js` is
// the source of truth at runtime; this function exists so the same
// transitions can be exercised in tests and (eventually) shared with
// the admin UI for showing what action will happen.
export function nextTeamStatusForUserStatus(
	userStatus: UserStatus
): TeamStatus | null {
	switch (userStatus) {
		case USER_STATUS.approved:
			return TEAM_STATUS.active;
		case USER_STATUS.rejected:
			return TEAM_STATUS.rejected;
		case USER_STATUS.pending:
			return null; // No transition; team stays pending.
	}
}
