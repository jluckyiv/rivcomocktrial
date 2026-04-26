export type Matchup<T> = {
	readonly higherSeed: T;
	readonly lowerSeed: T;
};

type Result<T> = { ok: true; value: T } | { ok: false; error: string };

export function bracket<T>(teams: T[]): Result<Matchup<T>[]> {
	if (teams.length !== 8) {
		return {
			ok: false,
			error: `Elimination bracket requires exactly 8 teams, got ${teams.length}`
		};
	}
	return {
		ok: true,
		value: [
			{ higherSeed: teams[0], lowerSeed: teams[7] },
			{ higherSeed: teams[1], lowerSeed: teams[6] },
			{ higherSeed: teams[2], lowerSeed: teams[5] },
			{ higherSeed: teams[3], lowerSeed: teams[4] }
		]
	};
}

export function higherSeed<T>(matchup: Matchup<T>): T {
	return matchup.higherSeed;
}

export function lowerSeed<T>(matchup: Matchup<T>): T {
	return matchup.lowerSeed;
}
