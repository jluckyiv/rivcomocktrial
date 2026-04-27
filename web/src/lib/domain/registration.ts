// Registration domain helpers. Pure functions over plain shapes — no
// PocketBase dependency.
//
// Team-side eligibility helpers live in ./eligibility.ts.

export const TOURNAMENT_STATUS = {
	draft: 'draft',
	registration: 'registration',
	active: 'active',
	completed: 'completed'
} as const;

export type TournamentStatus = (typeof TOURNAMENT_STATUS)[keyof typeof TOURNAMENT_STATUS];

export const USER_STATUS = {
	pending: 'pending',
	approved: 'approved',
	rejected: 'rejected'
} as const;

export type UserStatus = (typeof USER_STATUS)[keyof typeof USER_STATUS];

export function isTournamentOpenForRegistration(t: { status: string } | null | undefined): boolean {
	return t?.status === TOURNAMENT_STATUS.registration;
}
