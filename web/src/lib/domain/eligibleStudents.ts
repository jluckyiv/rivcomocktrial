export type StudentName = {
	readonly first: string
	readonly last: string
	readonly preferred?: string
}

export type Student = {
	readonly name: StudentName
	readonly pronouns: string
}

export type Config = {
	readonly minStudents: number
	readonly maxStudents: number
}

export const defaultConfig: Config = {
	minStudents: 8,
	maxStudents: 25,
}

export type Status = 'Draft' | 'Submitted' | 'Locked'

export type EligibleStudents<T> = {
	readonly team: T
	readonly students: readonly Student[]
	readonly status: Status
	readonly config: Config
}

type Result<T> = { ok: true; value: T } | { ok: false; error: string }

export function create<T>(config: Config, team: T): EligibleStudents<T> {
	return { team, students: [], status: 'Draft', config }
}

export function addStudent<T>(
	student: Student,
	es: EligibleStudents<T>
): Result<EligibleStudents<T>> {
	if (es.status !== 'Draft') {
		return { ok: false, error: 'Can only add students in Draft status' }
	}
	if (isDuplicate(student, es.students)) {
		return { ok: false, error: 'Student is already in the list' }
	}
	if (es.students.length >= es.config.maxStudents) {
		return { ok: false, error: `Cannot exceed ${es.config.maxStudents} students` }
	}
	return { ok: true, value: { ...es, students: [...es.students, student] } }
}

export function removeStudent<T>(student: Student, es: EligibleStudents<T>): EligibleStudents<T> {
	if (es.status !== 'Draft') return es
	return { ...es, students: es.students.filter((s) => !sameStudent(s, student)) }
}

export function submit<T>(es: EligibleStudents<T>): Result<EligibleStudents<T>> {
	if (es.status !== 'Draft') {
		return { ok: false, error: 'Can only submit from Draft status' }
	}
	if (es.students.length < es.config.minStudents) {
		return {
			ok: false,
			error: `Need at least ${es.config.minStudents} students, have ${es.students.length}`,
		}
	}
	return { ok: true, value: { ...es, status: 'Submitted' } }
}

export function lock<T>(es: EligibleStudents<T>): Result<EligibleStudents<T>> {
	if (es.status !== 'Submitted') {
		return { ok: false, error: 'Can only lock from Submitted status' }
	}
	return { ok: true, value: { ...es, status: 'Locked' } }
}

export function statusToString(s: Status): string {
	return s
}

function isDuplicate(student: Student, list: readonly Student[]): boolean {
	return list.some((s) => sameStudent(s, student))
}

function sameStudent(a: Student, b: Student): boolean {
	return a.name.first === b.name.first && a.name.last === b.name.last
}
