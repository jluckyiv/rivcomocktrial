import { type MatchHistory, hasPlayed, sideHistory, toRecords } from './matchHistory';

export type CrossBracketStrategy = 'HighHigh' | 'HighLow';

export type RankedTeam<T> = {
	team: T;
	wins: number;
	losses: number;
	rank: number;
};

export type ProposedPairing<T> = {
	prosecutionTeam: T;
	defenseTeam: T;
};

export type PowerMatchResult<T> = {
	pairings: ProposedPairing<T>[];
	warnings: string[];
};

export function powerMatch<T>(
	strategy: CrossBracketStrategy,
	rankedTeams: RankedTeam<T>[],
	allHistory: MatchHistory<T>,
	currentRoundHistory: MatchHistory<T>
): PowerMatchResult<T> {
	const pairedTeams = currentRoundPairedTeams(currentRoundHistory);
	const available = rankedTeams.filter((rt) => !pairedTeams.some((t) => t === rt.team));
	const brackets = groupByWins(available);
	const [withinPairs, spillover] = pairWithinBrackets(allHistory, brackets);
	const crossPairs = pairCrossBracket(strategy, allHistory, spillover);
	const allPairs = [...withinPairs, ...crossPairs];
	const pairings = allPairs.map((pair) => assignSides(allHistory, pair));
	return { pairings, warnings: [] };
}

function currentRoundPairedTeams<T>(history: MatchHistory<T>): T[] {
	return toRecords(history).flatMap((r) => [r.prosecution, r.defense]);
}

// GROUPING

function groupByWins<T>(teams: RankedTeam<T>[]): [number, RankedTeam<T>[]][] {
	const sorted = [...teams].sort((a, b) => b.wins - a.wins || a.rank - b.rank);
	const result: [number, RankedTeam<T>[]][] = [];
	for (const rt of sorted) {
		const last = result[result.length - 1];
		if (last && last[0] === rt.wins) {
			last[1].push(rt);
		} else {
			result.push([rt.wins, [rt]]);
		}
	}
	return result;
}

// WITHIN-BRACKET PAIRING

function pairWithinBrackets<T>(
	allHistory: MatchHistory<T>,
	brackets: [number, RankedTeam<T>[]][]
): [[RankedTeam<T>, RankedTeam<T>][], RankedTeam<T>[]] {
	const allPairs: [RankedTeam<T>, RankedTeam<T>][] = [];
	const allSpill: RankedTeam<T>[] = [];
	for (const [, bracketTeams] of brackets) {
		const [pairs, spill] = pairWithinBracket(allHistory, bracketTeams);
		allPairs.push(...pairs);
		allSpill.push(...spill);
	}
	return [allPairs, allSpill];
}

function pairWithinBracket<T>(
	allHistory: MatchHistory<T>,
	teams: RankedTeam<T>[]
): [[RankedTeam<T>, RankedTeam<T>][], RankedTeam<T>[]] {
	const sorted = [...teams].sort((a, b) => a.rank - b.rank);
	return pairTopBottom(allHistory, sorted, [], []);
}

function pairTopBottom<T>(
	allHistory: MatchHistory<T>,
	remaining: RankedTeam<T>[],
	pairs: [RankedTeam<T>, RankedTeam<T>][],
	spill: RankedTeam<T>[]
): [[RankedTeam<T>, RankedTeam<T>][], RankedTeam<T>[]] {
	if (remaining.length === 0) return [[...pairs].reverse(), spill];
	if (remaining.length === 1) return [[...pairs].reverse(), [remaining[0], ...spill]];

	const top = remaining[0];
	const rest = remaining.slice(1);
	const found = findPartnerFromBottom(allHistory, top, rest);
	if (found) {
		const [partner, restWithout] = found;
		return pairTopBottom(allHistory, restWithout, [[top, partner], ...pairs], spill);
	} else {
		return pairTopBottom(allHistory, rest, pairs, [top, ...spill]);
	}
}

function findPartnerFromBottom<T>(
	allHistory: MatchHistory<T>,
	top: RankedTeam<T>,
	candidates: RankedTeam<T>[]
): [RankedTeam<T>, RankedTeam<T>[]] | null {
	return findFromEnd(allHistory, top, [...candidates].reverse(), []);
}

function findFromEnd<T>(
	allHistory: MatchHistory<T>,
	top: RankedTeam<T>,
	reversed: RankedTeam<T>[],
	skipped: RankedTeam<T>[]
): [RankedTeam<T>, RankedTeam<T>[]] | null {
	if (reversed.length === 0) return null;
	const [candidate, ...rest] = reversed;
	if (canPair(allHistory, top, candidate)) {
		const remaining = [...rest].reverse().concat([...skipped].reverse());
		return [candidate, remaining];
	}
	return findFromEnd(allHistory, top, rest, [candidate, ...skipped]);
}

// CROSS-BRACKET PAIRING

function pairCrossBracket<T>(
	strategy: CrossBracketStrategy,
	allHistory: MatchHistory<T>,
	spillover: RankedTeam<T>[]
): [RankedTeam<T>, RankedTeam<T>][] {
	const sorted = [...spillover].sort((a, b) => b.wins - a.wins || a.rank - b.rank);
	return backtrackPairCross(strategy, allHistory, sorted) ?? [];
}

function backtrackPairCross<T>(
	strategy: CrossBracketStrategy,
	allHistory: MatchHistory<T>,
	remaining: RankedTeam<T>[]
): [RankedTeam<T>, RankedTeam<T>][] | null {
	if (remaining.length === 0) return [];
	if (remaining.length === 1) return [];

	const [first, ...rest] = remaining;
	const candidates = strategy === 'HighHigh' ? rest : [...rest].reverse();
	return tryPartners(strategy, allHistory, first, candidates, []);
}

function tryPartners<T>(
	strategy: CrossBracketStrategy,
	allHistory: MatchHistory<T>,
	team: RankedTeam<T>,
	candidates: RankedTeam<T>[],
	skipped: RankedTeam<T>[]
): [RankedTeam<T>, RankedTeam<T>][] | null {
	if (candidates.length === 0) return null;

	const [candidate, ...rest] = candidates;
	if (canPair(allHistory, team, candidate)) {
		const restWithout = [...skipped].reverse().concat(rest);
		const morePairs = backtrackPairCross(strategy, allHistory, restWithout);
		if (morePairs !== null) return [[team, candidate], ...morePairs];
		return tryPartners(strategy, allHistory, team, rest, [candidate, ...skipped]);
	}
	return tryPartners(strategy, allHistory, team, rest, [candidate, ...skipped]);
}

// CONSTRAINTS

function canPair<T>(allHistory: MatchHistory<T>, a: RankedTeam<T>, b: RankedTeam<T>): boolean {
	return !hasPlayed(allHistory, a.team, b.team) && !sameSideConflict(allHistory, a, b);
}

function sameSideConflict<T>(
	allHistory: MatchHistory<T>,
	a: RankedTeam<T>,
	b: RankedTeam<T>
): boolean {
	const aSides = sideHistory(allHistory, a.team);
	const bSides = sideHistory(allHistory, b.team);
	const aNeeds = neededSide(aSides);
	const bNeeds = neededSide(bSides);
	return aNeeds !== null && bNeeds !== null && aNeeds === bNeeds;
}

type Side = 'Prosecution' | 'Defense';

function neededSide(sides: { prosecution: number; defense: number }): Side | null {
	if (sides.prosecution > sides.defense) return 'Defense';
	if (sides.defense > sides.prosecution) return 'Prosecution';
	return null;
}

// SIDE ASSIGNMENT

function assignSides<T>(
	allHistory: MatchHistory<T>,
	[a, b]: [RankedTeam<T>, RankedTeam<T>]
): ProposedPairing<T> {
	const aSides = sideHistory(allHistory, a.team);
	const bSides = sideHistory(allHistory, b.team);
	if (aSides.prosecution <= bSides.prosecution) {
		return { prosecutionTeam: a.team, defenseTeam: b.team };
	}
	return { prosecutionTeam: b.team, defenseTeam: a.team };
}
