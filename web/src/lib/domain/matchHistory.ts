export type MatchRecord<T> = {
	readonly prosecution: T;
	readonly defense: T;
};

export type SideCount = {
	readonly prosecution: number;
	readonly defense: number;
};

export type MatchHistory<T> = {
	readonly records: readonly MatchRecord<T>[];
};

export function empty<T>(): MatchHistory<T> {
	return { records: [] };
}

export function fromRecords<T>(records: MatchRecord<T>[]): MatchHistory<T> {
	return { records: [...records] };
}

export function toRecords<T>(history: MatchHistory<T>): MatchRecord<T>[] {
	return [...history.records];
}

export function hasPlayed<T>(history: MatchHistory<T>, teamA: T, teamB: T): boolean {
	return history.records.some(
		(r) =>
			(r.prosecution === teamA && r.defense === teamB) ||
			(r.prosecution === teamB && r.defense === teamA)
	);
}

export function sideHistory<T>(history: MatchHistory<T>, team: T): SideCount {
	return history.records.reduce(
		(acc, r) => {
			if (r.prosecution === team) return { ...acc, prosecution: acc.prosecution + 1 };
			if (r.defense === team) return { ...acc, defense: acc.defense + 1 };
			return acc;
		},
		{ prosecution: 0, defense: 0 }
	);
}
