export type TeamRecord = {
	wins: number
	losses: number
	pointsFor: number
	pointsAgainst: number
}

export function teamRecord(r: {
	wins: number
	losses: number
	pointsFor: number
	pointsAgainst: number
}): TeamRecord {
	return { wins: r.wins, losses: r.losses, pointsFor: r.pointsFor, pointsAgainst: r.pointsAgainst }
}

export function wins(r: TeamRecord): number {
	return r.wins
}

export function losses(r: TeamRecord): number {
	return r.losses
}

export function pointsFor(r: TeamRecord): number {
	return r.pointsFor
}

export function pointsAgainst(r: TeamRecord): number {
	return r.pointsAgainst
}

export function cumulativePercentage(r: TeamRecord): number {
	const total = r.pointsFor + r.pointsAgainst
	return total === 0 ? 0 : r.pointsFor / total
}

export type Tiebreaker<T> =
	| { type: 'ByWins' }
	| { type: 'ByCumulativePercentage' }
	| { type: 'ByPointDifferential' }
	| { type: 'ByHeadToHead'; compare: (a: T, b: T) => number }

export const ByWins = { type: 'ByWins' } as const
export const ByCumulativePercentage = { type: 'ByCumulativePercentage' } as const
export const ByPointDifferential = { type: 'ByPointDifferential' } as const

export function ByHeadToHead<T>(compare: (a: T, b: T) => number): Tiebreaker<T> {
	return { type: 'ByHeadToHead', compare }
}

export type RankingStrategy<T> = Tiebreaker<T>[]

export function rank<T>(
	strategy: RankingStrategy<T>,
	entries: [T, TeamRecord][]
): [T, TeamRecord][] {
	return [...entries].sort((a, b) => compareByStrategy(strategy, a, b))
}

function compareByStrategy<T>(
	strategy: RankingStrategy<T>,
	a: [T, TeamRecord],
	b: [T, TeamRecord]
): number {
	for (const tiebreaker of strategy) {
		const result = compareByTiebreaker(tiebreaker, a, b)
		if (result !== 0) return result
	}
	return 0
}

function compareByTiebreaker<T>(
	tiebreaker: Tiebreaker<T>,
	a: [T, TeamRecord],
	b: [T, TeamRecord]
): number {
	switch (tiebreaker.type) {
		case 'ByWins':
			return b[1].wins - a[1].wins
		case 'ByCumulativePercentage':
			return cumulativePercentage(b[1]) - cumulativePercentage(a[1])
		case 'ByPointDifferential':
			return b[1].pointsFor - b[1].pointsAgainst - (a[1].pointsFor - a[1].pointsAgainst)
		case 'ByHeadToHead':
			return tiebreaker.compare(a[0], b[0])
	}
}
