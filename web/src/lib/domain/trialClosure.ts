export type ScorerStatus = 'AwaitingSubmissions' | 'AwaitingVerification' | 'AllVerified'

export type ActiveTrialStatus = 'AwaitingCheckIn' | 'InProgress' | 'Complete' | 'Verified'

export type BallotTracking = { scorerStatus: ScorerStatus }

export type ActiveTrial = { status: ActiveTrialStatus }

type Result<T> = { ok: true; value: T } | { ok: false; error: string }

export function completeTrial(tracking: BallotTracking, activeTrial: ActiveTrial): Result<ActiveTrial> {
	const ballotError =
		tracking.scorerStatus === 'AwaitingSubmissions'
			? 'Cannot complete trial: not all ballots submitted'
			: null

	const statusResult: Result<ActiveTrial> =
		activeTrial.status === 'InProgress'
			? { ok: true, value: { ...activeTrial, status: 'Complete' } }
			: { ok: false, error: `Cannot complete trial: status is ${activeTrial.status}` }

	if (!ballotError) return statusResult
	if (!statusResult.ok) return { ok: false, error: `${ballotError}; ${statusResult.error}` }
	return { ok: false, error: ballotError }
}

export function verifyTrial(tracking: BallotTracking, activeTrial: ActiveTrial): Result<ActiveTrial> {
	const ballotError =
		tracking.scorerStatus !== 'AllVerified'
			? 'Cannot verify trial: not all ballots verified'
			: null

	const statusResult: Result<ActiveTrial> =
		activeTrial.status === 'Complete'
			? { ok: true, value: { ...activeTrial, status: 'Verified' } }
			: { ok: false, error: `Cannot verify trial: status is ${activeTrial.status}` }

	if (!ballotError) return statusResult
	if (!statusResult.ok) return { ok: false, error: `${ballotError}; ${statusResult.error}` }
	return { ok: false, error: ballotError }
}
