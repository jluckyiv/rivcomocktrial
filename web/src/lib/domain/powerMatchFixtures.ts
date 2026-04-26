import { empty, fromRecords, type MatchHistory, type MatchRecord } from './matchHistory';

export { empty, fromRecords };
import { type RankedTeam } from './powerMatch';

export type Team = { id: string; number: number; name: string };

export function makeTeam(number: number, name: string): Team {
	return { id: String(number), number, name };
}

export function makeRankedTeam(
	number: number,
	name: string,
	wins: number,
	losses: number,
	rank: number
): RankedTeam<Team> {
	return { team: makeTeam(number, name), wins, losses, rank };
}

export function rankedTeam(
	team: Team,
	wins: number,
	losses: number,
	rank: number
): RankedTeam<Team> {
	return { team, wins, losses, rank };
}

// 26 TEAMS (2026 competition)

export const team01 = makeTeam(1, 'Palm Desert');
export const team02 = makeTeam(2, 'Santiago');
export const team03 = makeTeam(3, 'Vista del Lago');
export const team04 = makeTeam(4, 'Murrieta Valley');
export const team05 = makeTeam(5, 'Patriot');
export const team06 = makeTeam(6, 'La Quinta');
export const team08 = makeTeam(8, 'Norco');
export const team09 = makeTeam(9, 'Notre Dame');
export const team10 = makeTeam(10, 'Valley View');
export const team11 = makeTeam(11, 'Canyon Springs');
export const team12 = makeTeam(12, 'Temecula Valley');
export const team13 = makeTeam(13, 'Poly');
export const team14 = makeTeam(14, 'Heritage');
export const team15 = makeTeam(15, 'Indio');
export const team16 = makeTeam(16, 'Ramona');
export const team17 = makeTeam(17, 'Liberty');
export const team19 = makeTeam(19, 'John W. North');
export const team20 = makeTeam(20, 'Hemet');
export const team21 = makeTeam(21, 'Great Oak');
export const team22 = makeTeam(22, 'Chaparral');
export const team23 = makeTeam(23, 'Paloma Valley');
export const team24 = makeTeam(24, 'Palo Verde');
export const team25 = makeTeam(25, 'St. Jeanne de Lestonnac');
export const team26 = makeTeam(26, 'Centennial');
export const team27 = makeTeam(27, 'Martin Luther King');
export const team28 = makeTeam(28, 'San Jacinto');

export const allTeams: Team[] = [
	team01,
	team02,
	team03,
	team04,
	team05,
	team06,
	team08,
	team09,
	team10,
	team11,
	team12,
	team13,
	team14,
	team15,
	team16,
	team17,
	team19,
	team20,
	team21,
	team22,
	team23,
	team24,
	team25,
	team26,
	team27,
	team28
];

function r(prosecution: Team, defense: Team): MatchRecord<Team> {
	return { prosecution, defense };
}

// ROUND HISTORIES

const round1Records: MatchRecord<Team>[] = [
	r(team06, team15),
	r(team24, team01),
	r(team19, team09),
	r(team08, team11),
	r(team05, team27),
	r(team26, team13),
	r(team10, team02),
	r(team03, team16),
	r(team04, team14),
	r(team28, team25),
	r(team22, team17),
	r(team21, team12),
	r(team23, team20)
];

const round2Records: MatchRecord<Team>[] = [
	r(team09, team23),
	r(team02, team19),
	r(team27, team21),
	r(team16, team22),
	r(team13, team04),
	r(team12, team06),
	r(team25, team03),
	r(team15, team05),
	r(team11, team24),
	r(team20, team26),
	r(team14, team28),
	r(team17, team10),
	r(team01, team08)
];

const round3Records: MatchRecord<Team>[] = [
	r(team25, team01),
	r(team28, team05),
	r(team23, team17),
	r(team20, team12),
	r(team06, team03),
	r(team04, team02),
	r(team26, team14),
	r(team10, team08),
	r(team19, team16),
	r(team22, team09),
	r(team21, team24),
	r(team15, team11),
	r(team27, team13)
];

const round4Records: MatchRecord<Team>[] = [
	r(team02, team15),
	r(team16, team25),
	r(team13, team21),
	r(team24, team26),
	r(team12, team22),
	r(team11, team28),
	r(team05, team10),
	r(team01, team27),
	r(team03, team23),
	r(team08, team04),
	r(team14, team06),
	r(team17, team19),
	r(team09, team20)
];

export const round1History: MatchHistory<Team> = fromRecords(round1Records);
export const round2History: MatchHistory<Team> = fromRecords(round2Records);
export const round3History: MatchHistory<Team> = fromRecords(round3Records);
export const round4History: MatchHistory<Team> = fromRecords(round4Records);

export function historyThrough(roundNum: number): MatchHistory<Team> {
	const rounds: [number, MatchRecord<Team>[]][] = [
		[1, round1Records],
		[2, round2Records],
		[3, round3Records],
		[4, round4Records]
	];
	const records = rounds.filter(([n]) => n <= roundNum).flatMap(([, recs]) => recs);
	return fromRecords(records);
}
