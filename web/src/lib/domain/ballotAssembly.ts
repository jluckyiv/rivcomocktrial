export type Side = 'Prosecution' | 'Defense';
export type RosterSide = Side;

export type PresentationKind =
	| 'Pretrial'
	| 'Opening'
	| 'DirectExamination'
	| 'CrossExamination'
	| 'Closing'
	| 'WitnessExamination'
	| 'ClerkPerformance'
	| 'BailiffPerformance';

export type Weight = 'Single' | 'Double';

export type BallotScore = {
	id: string;
	ballot: string;
	presentation: PresentationKind;
	side: RosterSide;
	studentName: string;
	rosterEntry: string | null;
	points: number;
	sortOrder: number;
	created: string;
	updated: string;
};

export type BallotCorrection = {
	id: string;
	ballot: string;
	originalScoreId: string;
	correctedPoints: number;
	reason: string | null;
	correctedAt: string;
	created: string;
	updated: string;
};

export type PresiderBallotRecord = {
	id: string;
	scorerToken: string;
	trial: string;
	winnerSide: RosterSide;
	motionRuling: string | null;
	verdict: string | null;
	submittedAt: string;
	created: string;
	updated: string;
};

export type ScoredPresentation = {
	readonly presentationType: PresentationKind;
	readonly side: Side;
	readonly firstName: string;
	readonly lastName: string;
	readonly points: number;
	readonly weight: Weight;
};

export type SubmittedBallot = {
	readonly presentations: readonly ScoredPresentation[];
};

export type VerifiedBallot = {
	readonly original: SubmittedBallot;
	readonly presentations: readonly ScoredPresentation[];
};

export type PresiderBallot = {
	readonly winner: Side;
};

type Result<T> = { ok: true; value: T } | { ok: false; error: string };

export function assembleScoredPresentation(score: BallotScore): Result<ScoredPresentation> {
	const pointsResult = validatePoints(score.points);
	if (!pointsResult.ok) return pointsResult;
	const { firstName, lastName } = parseStudentName(score.studentName);
	return {
		ok: true,
		value: {
			presentationType: score.presentation,
			side: presentationSide(score.presentation, score.side),
			firstName,
			lastName,
			points: pointsResult.value,
			weight: presentationWeight(score.presentation)
		}
	};
}

export function assembleSubmittedBallot(scores: BallotScore[]): Result<SubmittedBallot> {
	if (scores.length === 0) return { ok: false, error: 'No scores provided' };
	const sorted = [...scores].sort((a, b) => a.sortOrder - b.sortOrder);
	return collectPresentations(sorted);
}

export function assembleVerifiedBallot(
	original: SubmittedBallot,
	scores: BallotScore[],
	corrections: BallotCorrection[]
): Result<VerifiedBallot> {
	if (corrections.length === 0) {
		return { ok: true, value: { original, presentations: original.presentations } };
	}
	const correctionMap = new Map(corrections.map((c) => [c.originalScoreId, c.correctedPoints]));
	const correctedScores = scores.map((score) => {
		const corrected = correctionMap.get(score.id);
		return corrected !== undefined ? { ...score, points: corrected } : score;
	});
	const sorted = [...correctedScores].sort((a, b) => a.sortOrder - b.sortOrder);
	const result = collectPresentations(sorted);
	if (!result.ok) return result;
	return { ok: true, value: { original, presentations: result.value.presentations } };
}

export function assemblePresiderBallot(record: PresiderBallotRecord): PresiderBallot {
	return { winner: record.winnerSide };
}

function collectPresentations(scores: BallotScore[]): Result<SubmittedBallot> {
	const errors: string[] = [];
	const presentations: ScoredPresentation[] = [];
	for (const score of scores) {
		const result = assembleScoredPresentation(score);
		if (result.ok) presentations.push(result.value);
		else errors.push(result.error);
	}
	if (errors.length > 0) return { ok: false, error: errors.join('; ') };
	return { ok: true, value: { presentations } };
}

function validatePoints(points: number): Result<number> {
	if (points >= 1 && points <= 10) return { ok: true, value: points };
	return { ok: false, error: `Points ${points} out of range (1–10)` };
}

function parseStudentName(fullName: string): { firstName: string; lastName: string } {
	const words = fullName.trim().split(' ').filter(Boolean);
	if (words.length === 0) return { firstName: '—', lastName: '' };
	const lastName = words[words.length - 1];
	const firstName = words.length > 1 ? words.slice(0, -1).join(' ') : '—';
	return { firstName, lastName };
}

function presentationWeight(kind: PresentationKind): Weight {
	return kind === 'Pretrial' || kind === 'Closing' ? 'Double' : 'Single';
}

function presentationSide(kind: PresentationKind, apiSide: RosterSide): Side {
	if (kind === 'ClerkPerformance') return 'Prosecution';
	if (kind === 'BailiffPerformance') return 'Defense';
	return apiSide;
}
