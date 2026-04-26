import { describe, expect, test } from 'vitest';
import {
	addStudent,
	create,
	defaultConfig,
	lock,
	removeStudent,
	statusToString,
	submit,
	type EligibleStudents,
	type Student
} from './eligibleStudents';

type Team = { id: string; name: string };

const sampleTeam: Team = { id: '1', name: 'Palm Desert' };

function makeStudent(first: string, last: string, pronouns: string): Student {
	return { name: { first, last }, pronouns };
}

const sampleStudent = makeStudent('Jordan', 'Smith', 'they/them');

const eightStudents: Student[] = [
	makeStudent('Alex', 'Chen', 'he/him'),
	makeStudent('Maria', 'Garcia', 'she/her'),
	makeStudent('Jordan', 'Smith', 'they/them'),
	makeStudent('Sam', 'Johnson', 'he/him'),
	makeStudent('Riley', 'Williams', 'she/her'),
	makeStudent('Taylor', 'Brown', 'they/them'),
	makeStudent('Morgan', 'Davis', 'he/him'),
	makeStudent('Casey', 'Miller', 'she/her')
];

function addAll(
	students: Student[],
	es: EligibleStudents<Team>
): { ok: true; value: EligibleStudents<Team> } | { ok: false; error: string } {
	return students.reduce((acc, s) => (acc.ok ? addStudent(s, acc.value) : acc), {
		ok: true,
		value: es
	} as ReturnType<typeof addStudent<Team>>);
}

function makeSubmitted(): EligibleStudents<Team> {
	const result = addAll(eightStudents, create(defaultConfig, sampleTeam));
	if (!result.ok) throw new Error('Failed to create submitted eligible students');
	const submitted = submit(result.value);
	if (!submitted.ok) throw new Error('Failed to submit eligible students');
	return submitted.value;
}

describe('EligibleStudents', () => {
	describe('defaultConfig', () => {
		test('minStudents is 8 (Rule 2.2A)', () => {
			expect(defaultConfig.minStudents).toBe(8);
		});
		test('maxStudents is 25 (Rule 2.2A)', () => {
			expect(defaultConfig.maxStudents).toBe(25);
		});
	});

	describe('create', () => {
		test('returns Draft status', () => {
			expect(create(defaultConfig, sampleTeam).status).toBe('Draft');
		});
		test('returns empty student list', () => {
			expect(create(defaultConfig, sampleTeam).students.length).toBe(0);
		});
		test('returns the team', () => {
			expect(create(defaultConfig, sampleTeam).team.name).toBe('Palm Desert');
		});
		test('stores config', () => {
			const cfg = { minStudents: 5, maxStudents: 15 };
			expect(create(cfg, sampleTeam).config).toEqual(cfg);
		});
	});

	describe('addStudent', () => {
		test('in Draft succeeds', () => {
			const result = addStudent(sampleStudent, create(defaultConfig, sampleTeam));
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.students.length).toBe(1);
		});
		test('rejects duplicates', () => {
			const first = addStudent(sampleStudent, create(defaultConfig, sampleTeam));
			if (!first.ok) throw new Error('First add failed');
			const second = addStudent(sampleStudent, first.value);
			expect(second.ok).toBe(false);
		});
		test('in Submitted fails', () => {
			const result = addStudent(sampleStudent, makeSubmitted());
			expect(result.ok).toBe(false);
		});
		test('rejects when at maxStudents', () => {
			const cfg = { minStudents: 2, maxStudents: 3 };
			const threeStudents = [
				makeStudent('A', 'One', 'he/him'),
				makeStudent('B', 'Two', 'she/her'),
				makeStudent('C', 'Three', 'they/them')
			];
			const extra = makeStudent('D', 'Four', 'he/him');
			const filled = addAll(threeStudents, create(cfg, sampleTeam));
			if (!filled.ok) throw new Error('Fill failed');
			expect(addStudent(extra, filled.value).ok).toBe(false);
		});
	});

	describe('removeStudent', () => {
		test('in Draft removes student', () => {
			const added = addStudent(sampleStudent, create(defaultConfig, sampleTeam));
			if (!added.ok) throw new Error('Add failed');
			expect(removeStudent(sampleStudent, added.value).students.length).toBe(0);
		});
		test('in Submitted is no-op', () => {
			const submitted = makeSubmitted();
			const firstStudent = submitted.students[0];
			expect(removeStudent(firstStudent, submitted).students.length).toBe(8);
		});
	});

	describe('submit', () => {
		test('with >= minStudents transitions to Submitted', () => {
			expect(makeSubmitted().status).toBe('Submitted');
		});
		test('with < minStudents fails', () => {
			const one = addStudent(sampleStudent, create(defaultConfig, sampleTeam));
			if (!one.ok) throw new Error('Add failed');
			expect(submit(one.value).ok).toBe(false);
		});
		test('respects custom minStudents', () => {
			const cfg = { minStudents: 3, maxStudents: 25 };
			const threeStudents = [
				makeStudent('A', 'One', 'he/him'),
				makeStudent('B', 'Two', 'she/her'),
				makeStudent('C', 'Three', 'they/them')
			];
			const filled = addAll(threeStudents, create(cfg, sampleTeam));
			if (!filled.ok) throw new Error('Fill failed');
			const result = submit(filled.value);
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.status).toBe('Submitted');
		});
		test('when not Draft fails', () => {
			expect(submit(makeSubmitted()).ok).toBe(false);
		});
	});

	describe('lock', () => {
		test('from Submitted transitions to Locked', () => {
			const result = lock(makeSubmitted());
			expect(result.ok).toBe(true);
			if (result.ok) expect(result.value.status).toBe('Locked');
		});
		test('from Draft fails', () => {
			expect(lock(create(defaultConfig, sampleTeam)).ok).toBe(false);
		});
	});

	describe('statusToString', () => {
		test('Draft', () => {
			expect(statusToString('Draft')).toBe('Draft');
		});
		test('Submitted', () => {
			expect(statusToString('Submitted')).toBe('Submitted');
		});
		test('Locked', () => {
			expect(statusToString('Locked')).toBe('Locked');
		});
	});
});
