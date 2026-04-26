export type Side = 'Prosecution' | 'Defense'

export type Trial<T> = {
	readonly prosecution: T
	readonly defense: T
}

export type MeetingHistory =
	| { kind: 'FirstMeeting'; mostRecentSide: Side }
	| { kind: 'Rematch'; priorSide: Side }
	| { kind: 'ThirdMeeting' }

type Result<T> = { ok: true; value: T } | { ok: false; error: string }

export function meetingHistory<T>(
	higherSeedTeam: T,
	lowerSeedTeam: T,
	trials: Trial<T>[],
	mostRecentSide: Side
): MeetingHistory {
	const priorMeetings = trials.filter((t) => involves(higherSeedTeam, lowerSeedTeam, t))
	if (priorMeetings.length === 0) {
		return { kind: 'FirstMeeting', mostRecentSide }
	}
	if (priorMeetings.length === 1) {
		const trial = priorMeetings[0]
		const priorSide: Side = trial.prosecution === higherSeedTeam ? 'Prosecution' : 'Defense'
		return { kind: 'Rematch', priorSide }
	}
	return { kind: 'ThirdMeeting' }
}

export function elimSide(history: MeetingHistory): Result<Side> {
	switch (history.kind) {
		case 'FirstMeeting':
			return { ok: true, value: flip(history.mostRecentSide) }
		case 'Rematch':
			return { ok: true, value: flip(history.priorSide) }
		case 'ThirdMeeting':
			return { ok: false, error: 'Coin flip required for third meeting' }
	}
}

export function elimSideAssignment(history: MeetingHistory): Result<[Side, Side]> {
	const result = elimSide(history)
	if (!result.ok) return result
	return { ok: true, value: [result.value, flip(result.value)] }
}

function flip(side: Side): Side {
	return side === 'Prosecution' ? 'Defense' : 'Prosecution'
}

function involves<T>(a: T, b: T, trial: Trial<T>): boolean {
	return (
		(trial.prosecution === a && trial.defense === b) ||
		(trial.prosecution === b && trial.defense === a)
	)
}
