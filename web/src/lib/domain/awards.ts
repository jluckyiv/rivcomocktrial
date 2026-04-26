export type Side = 'Prosecution' | 'Defense';

export type NominationCategory = 'Advocate' | 'NonAdvocate';

export type AwardTiebreaker = 'ByRawScore';

export type Witness = { name: string; role: string };

export type AwardCategory =
	| { kind: 'BestAttorney'; side: Side }
	| { kind: 'BestWitness'; witness: Witness }
	| { kind: 'BestClerk' }
	| { kind: 'BestBailiff' };

export type Student = { firstName: string; lastName: string };

export type StudentScore = {
	student: Student;
	category: AwardCategory;
	totalRankPoints: number;
};

export function nominationCategory(category: AwardCategory): NominationCategory {
	switch (category.kind) {
		case 'BestAttorney':
			return 'Advocate';
		case 'BestWitness':
		case 'BestClerk':
		case 'BestBailiff':
			return 'NonAdvocate';
	}
}

export function scoreByRankPoints(entries: [Student, AwardCategory, number[]][]): StudentScore[] {
	const count = entries.length;
	return entries
		.map(([student, category, ranks]) => ({
			student,
			category,
			totalRankPoints: ranks
				.map((rank) => rankPoints(count, rank))
				.filter((p): p is number => p !== null)
				.reduce((sum, p) => sum + p, 0)
		}))
		.sort((a, b) => b.totalRankPoints - a.totalRankPoints);
}

function rankPoints(count: number, rank: number): number | null {
	if (count < 1 || rank < 1 || rank > 5) return null;
	return count + 1 - rank;
}
