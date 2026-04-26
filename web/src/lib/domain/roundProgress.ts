export type TrialStatus = 'AwaitingCheckIn' | 'InProgress' | 'Complete' | 'Verified';

export type RoundProgress =
	| 'CheckInOpen'
	| 'AllTrialsStarted'
	| 'AllTrialsComplete'
	| 'FullyVerified';

export function roundProgress(trials: { status: TrialStatus }[]): RoundProgress {
	const statuses = trials.map((t) => t.status);
	if (statuses.some((s) => s === 'AwaitingCheckIn')) return 'CheckInOpen';
	if (statuses.some((s) => s === 'InProgress')) return 'AllTrialsStarted';
	if (statuses.some((s) => s === 'Complete')) return 'AllTrialsComplete';
	return 'FullyVerified';
}

export function progressToString(progress: RoundProgress): string {
	switch (progress) {
		case 'CheckInOpen':
			return 'Check-In Open';
		case 'AllTrialsStarted':
			return 'All Trials Started';
		case 'AllTrialsComplete':
			return 'All Trials Complete';
		case 'FullyVerified':
			return 'Fully Verified';
	}
}
