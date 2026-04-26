/**
* This file was @generated using pocketbase-typegen
*/

import type PocketBase from 'pocketbase'
import type { RecordService } from 'pocketbase'

export const Collections = {
	Authorigins: "_authOrigins",
	Externalauths: "_externalAuths",
	Mfas: "_mfas",
	Otps: "_otps",
	Superusers: "_superusers",
	AttorneyCoaches: "attorney_coaches",
	AttorneyTasks: "attorney_tasks",
	BallotCorrections: "ballot_corrections",
	BallotScores: "ballot_scores",
	BallotSubmissions: "ballot_submissions",
	CaseCharacters: "case_characters",
	CoCoaches: "co_coaches",
	Courtrooms: "courtrooms",
	Districts: "districts",
	EligibilityChangeRequests: "eligibility_change_requests",
	EligibilityListEntries: "eligibility_list_entries",
	Judges: "judges",
	PresiderBallots: "presider_ballots",
	Registrations: "registrations",
	RosterEntries: "roster_entries",
	RosterSubmissions: "roster_submissions",
	Rounds: "rounds",
	Schools: "schools",
	ScorerTokens: "scorer_tokens",
	Students: "students",
	Teams: "teams",
	Tournaments: "tournaments",
	Trials: "trials",
	Users: "users",
	WithdrawalRequests: "withdrawal_requests",
} as const
export type Collections = typeof Collections[keyof typeof Collections]

// Alias types for improved usability
export type IsoDateString = string
export type IsoAutoDateString = string & { readonly autodate: unique symbol }
export type RecordIdString = string
export type FileNameString = string & { readonly filename: unique symbol }
export type HTMLString = string

type ExpandType<T> = unknown extends T
	? T extends unknown
		? { expand?: unknown }
		: { expand: T }
	: { expand: T }

// System fields
export type BaseSystemFields<T = unknown> = {
	id: RecordIdString
	collectionId: string
	collectionName: Collections
} & ExpandType<T>

export type AuthSystemFields<T = unknown> = {
	email: string
	emailVisibility: boolean
	username: string
	verified: boolean
} & BaseSystemFields<T>

// Record types for each collection

export type AuthoriginsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	fingerprint: string
	id: string
	recordRef: string
	updated: IsoAutoDateString
}

export type ExternalauthsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	provider: string
	providerId: string
	recordRef: string
	updated: IsoAutoDateString
}

export type MfasRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	method: string
	recordRef: string
	updated: IsoAutoDateString
}

export type OtpsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	password: string
	recordRef: string
	sentTo?: string
	updated: IsoAutoDateString
}

export type SuperusersRecord = {
	created: IsoAutoDateString
	email: string
	emailVisibility?: boolean
	id: string
	is_primary_contact?: boolean
	name?: string
	password: string
	tokenKey: string
	updated: IsoAutoDateString
	verified?: boolean
}

export type AttorneyCoachesRecord = {
	contact?: string
	created: IsoAutoDateString
	id: string
	name: string
	team: RecordIdString
	updated: IsoAutoDateString
}

export const AttorneyTasksTaskTypeOptions = {
	"opening": "opening",
	"direct": "direct",
	"cross": "cross",
	"closing": "closing",
} as const
export type AttorneyTasksTaskTypeOptions = typeof AttorneyTasksTaskTypeOptions[keyof typeof AttorneyTasksTaskTypeOptions]
export type AttorneyTasksRecord = {
	character?: RecordIdString
	created: IsoAutoDateString
	id: string
	roster_entry: RecordIdString
	sort_order?: number
	task_type: AttorneyTasksTaskTypeOptions
	updated: IsoAutoDateString
}

export type BallotCorrectionsRecord = {
	ballot: RecordIdString
	corrected_at: IsoDateString
	corrected_points: number
	created: IsoAutoDateString
	id: string
	original_score: RecordIdString
	reason?: string
	updated: IsoAutoDateString
}

export const BallotScoresPresentationOptions = {
	"pretrial": "pretrial",
	"opening": "opening",
	"direct_examination": "direct_examination",
	"cross_examination": "cross_examination",
	"closing": "closing",
	"witness_examination": "witness_examination",
	"clerk_performance": "clerk_performance",
	"bailiff_performance": "bailiff_performance",
} as const
export type BallotScoresPresentationOptions = typeof BallotScoresPresentationOptions[keyof typeof BallotScoresPresentationOptions]

export const BallotScoresSideOptions = {
	"prosecution": "prosecution",
	"defense": "defense",
} as const
export type BallotScoresSideOptions = typeof BallotScoresSideOptions[keyof typeof BallotScoresSideOptions]
export type BallotScoresRecord = {
	ballot: RecordIdString
	created: IsoAutoDateString
	id: string
	points: number
	presentation: BallotScoresPresentationOptions
	roster_entry?: RecordIdString
	side: BallotScoresSideOptions
	sort_order: number
	student_name: string
	updated: IsoAutoDateString
}

export const BallotSubmissionsStatusOptions = {
	"submitted": "submitted",
	"verified": "verified",
	"corrected": "corrected",
} as const
export type BallotSubmissionsStatusOptions = typeof BallotSubmissionsStatusOptions[keyof typeof BallotSubmissionsStatusOptions]
export type BallotSubmissionsRecord = {
	created: IsoAutoDateString
	id: string
	scorer_token: RecordIdString
	status: BallotSubmissionsStatusOptions
	submitted_at: IsoDateString
	trial: RecordIdString
	updated: IsoAutoDateString
}

export const CaseCharactersSideOptions = {
	"prosecution": "prosecution",
	"defense": "defense",
} as const
export type CaseCharactersSideOptions = typeof CaseCharactersSideOptions[keyof typeof CaseCharactersSideOptions]
export type CaseCharactersRecord = {
	character_name: string
	created: IsoAutoDateString
	description?: string
	id: string
	side: CaseCharactersSideOptions
	sort_order?: number
	tournament: RecordIdString
	updated: IsoAutoDateString
}

export type CoCoachesRecord = {
	created: IsoAutoDateString
	email?: string
	id: string
	name: string
	team: RecordIdString
	updated: IsoAutoDateString
}

export type CourtroomsRecord = {
	created: IsoAutoDateString
	id: string
	location?: string
	name: string
	updated: IsoAutoDateString
}

export type DistrictsRecord = {
	created: IsoAutoDateString
	id: string
	name: string
	updated: IsoAutoDateString
}

export const EligibilityChangeRequestsChangeTypeOptions = {
	"add": "add",
	"remove": "remove",
} as const
export type EligibilityChangeRequestsChangeTypeOptions = typeof EligibilityChangeRequestsChangeTypeOptions[keyof typeof EligibilityChangeRequestsChangeTypeOptions]

export const EligibilityChangeRequestsStatusOptions = {
	"pending": "pending",
	"approved": "approved",
	"rejected": "rejected",
} as const
export type EligibilityChangeRequestsStatusOptions = typeof EligibilityChangeRequestsStatusOptions[keyof typeof EligibilityChangeRequestsStatusOptions]
export type EligibilityChangeRequestsRecord = {
	change_type: EligibilityChangeRequestsChangeTypeOptions
	created: IsoAutoDateString
	id: string
	notes?: string
	status: EligibilityChangeRequestsStatusOptions
	student_name: string
	team: RecordIdString
	updated: IsoAutoDateString
}

export const EligibilityListEntriesStatusOptions = {
	"active": "active",
	"removed": "removed",
} as const
export type EligibilityListEntriesStatusOptions = typeof EligibilityListEntriesStatusOptions[keyof typeof EligibilityListEntriesStatusOptions]
export type EligibilityListEntriesRecord = {
	created: IsoAutoDateString
	id: string
	name: string
	status: EligibilityListEntriesStatusOptions
	team: RecordIdString
	tournament: RecordIdString
	updated: IsoAutoDateString
}

export type JudgesRecord = {
	created: IsoAutoDateString
	email?: string
	id: string
	name: string
	updated: IsoAutoDateString
}

export const PresiderBallotsWinnerSideOptions = {
	"prosecution": "prosecution",
	"defense": "defense",
} as const
export type PresiderBallotsWinnerSideOptions = typeof PresiderBallotsWinnerSideOptions[keyof typeof PresiderBallotsWinnerSideOptions]

export const PresiderBallotsMotionRulingOptions = {
	"granted": "granted",
	"denied": "denied",
} as const
export type PresiderBallotsMotionRulingOptions = typeof PresiderBallotsMotionRulingOptions[keyof typeof PresiderBallotsMotionRulingOptions]

export const PresiderBallotsVerdictOptions = {
	"guilty": "guilty",
	"not_guilty": "not_guilty",
} as const
export type PresiderBallotsVerdictOptions = typeof PresiderBallotsVerdictOptions[keyof typeof PresiderBallotsVerdictOptions]
export type PresiderBallotsRecord = {
	created: IsoAutoDateString
	id: string
	motion_ruling?: PresiderBallotsMotionRulingOptions
	scorer_token: RecordIdString
	submitted_at: IsoDateString
	trial: RecordIdString
	updated: IsoAutoDateString
	verdict?: PresiderBallotsVerdictOptions
	winner_side: PresiderBallotsWinnerSideOptions
}

export const RegistrationsStatusOptions = {
	"pending": "pending",
	"approved": "approved",
	"rejected": "rejected",
} as const
export type RegistrationsStatusOptions = typeof RegistrationsStatusOptions[keyof typeof RegistrationsStatusOptions]
export type RegistrationsRecord = {
	applicant_email: string
	created: IsoAutoDateString
	first_name: string
	id: string
	last_name: string
	school: RecordIdString
	status: RegistrationsStatusOptions
	team_name: string
	updated: IsoAutoDateString
}

export const RosterEntriesSideOptions = {
	"prosecution": "prosecution",
	"defense": "defense",
} as const
export type RosterEntriesSideOptions = typeof RosterEntriesSideOptions[keyof typeof RosterEntriesSideOptions]

export const RosterEntriesEntryTypeOptions = {
	"active": "active",
	"substitute": "substitute",
	"non_active": "non_active",
} as const
export type RosterEntriesEntryTypeOptions = typeof RosterEntriesEntryTypeOptions[keyof typeof RosterEntriesEntryTypeOptions]

export const RosterEntriesRoleOptions = {
	"pretrial_attorney": "pretrial_attorney",
	"trial_attorney": "trial_attorney",
	"witness": "witness",
	"clerk": "clerk",
	"bailiff": "bailiff",
	"artist": "artist",
	"journalist": "journalist",
} as const
export type RosterEntriesRoleOptions = typeof RosterEntriesRoleOptions[keyof typeof RosterEntriesRoleOptions]
export type RosterEntriesRecord = {
	character?: RecordIdString
	created: IsoAutoDateString
	entry_type: RosterEntriesEntryTypeOptions
	id: string
	role?: RosterEntriesRoleOptions
	round: RecordIdString
	side: RosterEntriesSideOptions
	sort_order?: number
	student?: RecordIdString
	team: RecordIdString
	updated: IsoAutoDateString
}

export const RosterSubmissionsSideOptions = {
	"prosecution": "prosecution",
	"defense": "defense",
} as const
export type RosterSubmissionsSideOptions = typeof RosterSubmissionsSideOptions[keyof typeof RosterSubmissionsSideOptions]
export type RosterSubmissionsRecord = {
	created: IsoAutoDateString
	id: string
	round: RecordIdString
	side: RosterSubmissionsSideOptions
	submitted_at?: IsoDateString
	team: RecordIdString
	updated: IsoAutoDateString
}

export const RoundsTypeOptions = {
	"preliminary": "preliminary",
	"elimination": "elimination",
} as const
export type RoundsTypeOptions = typeof RoundsTypeOptions[keyof typeof RoundsTypeOptions]

export const RoundsStatusOptions = {
	"upcoming": "upcoming",
	"open": "open",
	"locked": "locked",
} as const
export type RoundsStatusOptions = typeof RoundsStatusOptions[keyof typeof RoundsStatusOptions]
export type RoundsRecord = {
	created: IsoAutoDateString
	date?: string
	id: string
	number: number
	published?: boolean
	ranking_max?: number
	ranking_min?: number
	status: RoundsStatusOptions
	tournament: RecordIdString
	type: RoundsTypeOptions
	updated: IsoAutoDateString
}

export type SchoolsRecord = {
	created: IsoAutoDateString
	district?: RecordIdString
	id: string
	name: string
	nickname?: string
	updated: IsoAutoDateString
}

export const ScorerTokensScorerRoleOptions = {
	"scorer": "scorer",
	"presider": "presider",
} as const
export type ScorerTokensScorerRoleOptions = typeof ScorerTokensScorerRoleOptions[keyof typeof ScorerTokensScorerRoleOptions]

export const ScorerTokensStatusOptions = {
	"active": "active",
	"used": "used",
	"revoked": "revoked",
} as const
export type ScorerTokensStatusOptions = typeof ScorerTokensStatusOptions[keyof typeof ScorerTokensStatusOptions]
export type ScorerTokensRecord = {
	created: IsoAutoDateString
	id: string
	scorer_name?: string
	scorer_role: ScorerTokensScorerRoleOptions
	status: ScorerTokensStatusOptions
	token: string
	trial: RecordIdString
	updated: IsoAutoDateString
}

export type StudentsRecord = {
	created: IsoAutoDateString
	id: string
	name: string
	pronouns?: string
	school: RecordIdString
	updated: IsoAutoDateString
}

export const TeamsStatusOptions = {
	"pending": "pending",
	"active": "active",
	"withdrawn": "withdrawn",
	"rejected": "rejected",
} as const
export type TeamsStatusOptions = typeof TeamsStatusOptions[keyof typeof TeamsStatusOptions]
export type TeamsRecord = {
	coach?: RecordIdString
	created: IsoAutoDateString
	id: string
	name?: string
	school: RecordIdString
	status?: TeamsStatusOptions
	team_number?: number
	tournament: RecordIdString
	updated: IsoAutoDateString
}

export const TournamentsStatusOptions = {
	"draft": "draft",
	"registration": "registration",
	"active": "active",
	"completed": "completed",
} as const
export type TournamentsStatusOptions = typeof TournamentsStatusOptions[keyof typeof TournamentsStatusOptions]
export type TournamentsRecord = {
	created: IsoAutoDateString
	eligibility_locked_at?: IsoDateString
	id: string
	name: string
	num_elimination_rounds: number
	num_preliminary_rounds: number
	roster_deadline_hours?: number
	status: TournamentsStatusOptions
	updated: IsoAutoDateString
	year: number
}

export type TrialsRecord = {
	courtroom?: RecordIdString
	created: IsoAutoDateString
	defense_team: RecordIdString
	id: string
	judge?: RecordIdString
	prosecution_team: RecordIdString
	round: RecordIdString
	scorer_1?: RecordIdString
	scorer_2?: RecordIdString
	scorer_3?: RecordIdString
	scorer_4?: RecordIdString
	scorer_5?: RecordIdString
	updated: IsoAutoDateString
}

export const UsersRoleOptions = {
	"coach": "coach",
} as const
export type UsersRoleOptions = typeof UsersRoleOptions[keyof typeof UsersRoleOptions]

export const UsersStatusOptions = {
	"pending": "pending",
	"approved": "approved",
	"rejected": "rejected",
} as const
export type UsersStatusOptions = typeof UsersStatusOptions[keyof typeof UsersStatusOptions]
export type UsersRecord = {
	avatar?: FileNameString
	created: IsoAutoDateString
	email: string
	emailVisibility?: boolean
	id: string
	name?: string
	password: string
	role?: UsersRoleOptions
	school?: RecordIdString
	status?: UsersStatusOptions
	team_name?: string
	tokenKey: string
	updated: IsoAutoDateString
	verified?: boolean
}

export const WithdrawalRequestsStatusOptions = {
	"pending": "pending",
	"approved": "approved",
	"rejected": "rejected",
} as const
export type WithdrawalRequestsStatusOptions = typeof WithdrawalRequestsStatusOptions[keyof typeof WithdrawalRequestsStatusOptions]
export type WithdrawalRequestsRecord = {
	created: IsoAutoDateString
	id: string
	reason?: string
	status: WithdrawalRequestsStatusOptions
	team: RecordIdString
	updated: IsoAutoDateString
}

// Response types include system fields and match responses from the PocketBase API
export type AuthoriginsResponse<Texpand = unknown> = Required<AuthoriginsRecord> & BaseSystemFields<Texpand>
export type ExternalauthsResponse<Texpand = unknown> = Required<ExternalauthsRecord> & BaseSystemFields<Texpand>
export type MfasResponse<Texpand = unknown> = Required<MfasRecord> & BaseSystemFields<Texpand>
export type OtpsResponse<Texpand = unknown> = Required<OtpsRecord> & BaseSystemFields<Texpand>
export type SuperusersResponse<Texpand = unknown> = Required<SuperusersRecord> & AuthSystemFields<Texpand>
export type AttorneyCoachesResponse<Texpand = unknown> = Required<AttorneyCoachesRecord> & BaseSystemFields<Texpand>
export type AttorneyTasksResponse<Texpand = unknown> = Required<AttorneyTasksRecord> & BaseSystemFields<Texpand>
export type BallotCorrectionsResponse<Texpand = unknown> = Required<BallotCorrectionsRecord> & BaseSystemFields<Texpand>
export type BallotScoresResponse<Texpand = unknown> = Required<BallotScoresRecord> & BaseSystemFields<Texpand>
export type BallotSubmissionsResponse<Texpand = unknown> = Required<BallotSubmissionsRecord> & BaseSystemFields<Texpand>
export type CaseCharactersResponse<Texpand = unknown> = Required<CaseCharactersRecord> & BaseSystemFields<Texpand>
export type CoCoachesResponse<Texpand = unknown> = Required<CoCoachesRecord> & BaseSystemFields<Texpand>
export type CourtroomsResponse<Texpand = unknown> = Required<CourtroomsRecord> & BaseSystemFields<Texpand>
export type DistrictsResponse<Texpand = unknown> = Required<DistrictsRecord> & BaseSystemFields<Texpand>
export type EligibilityChangeRequestsResponse<Texpand = unknown> = Required<EligibilityChangeRequestsRecord> & BaseSystemFields<Texpand>
export type EligibilityListEntriesResponse<Texpand = unknown> = Required<EligibilityListEntriesRecord> & BaseSystemFields<Texpand>
export type JudgesResponse<Texpand = unknown> = Required<JudgesRecord> & BaseSystemFields<Texpand>
export type PresiderBallotsResponse<Texpand = unknown> = Required<PresiderBallotsRecord> & BaseSystemFields<Texpand>
export type RegistrationsResponse<Texpand = unknown> = Required<RegistrationsRecord> & BaseSystemFields<Texpand>
export type RosterEntriesResponse<Texpand = unknown> = Required<RosterEntriesRecord> & BaseSystemFields<Texpand>
export type RosterSubmissionsResponse<Texpand = unknown> = Required<RosterSubmissionsRecord> & BaseSystemFields<Texpand>
export type RoundsResponse<Texpand = unknown> = Required<RoundsRecord> & BaseSystemFields<Texpand>
export type SchoolsResponse<Texpand = unknown> = Required<SchoolsRecord> & BaseSystemFields<Texpand>
export type ScorerTokensResponse<Texpand = unknown> = Required<ScorerTokensRecord> & BaseSystemFields<Texpand>
export type StudentsResponse<Texpand = unknown> = Required<StudentsRecord> & BaseSystemFields<Texpand>
export type TeamsResponse<Texpand = unknown> = Required<TeamsRecord> & BaseSystemFields<Texpand>
export type TournamentsResponse<Texpand = unknown> = Required<TournamentsRecord> & BaseSystemFields<Texpand>
export type TrialsResponse<Texpand = unknown> = Required<TrialsRecord> & BaseSystemFields<Texpand>
export type UsersResponse<Texpand = unknown> = Required<UsersRecord> & AuthSystemFields<Texpand>
export type WithdrawalRequestsResponse<Texpand = unknown> = Required<WithdrawalRequestsRecord> & BaseSystemFields<Texpand>

// Types containing all Records and Responses, useful for creating typing helper functions

export type CollectionRecords = {
	_authOrigins: AuthoriginsRecord
	_externalAuths: ExternalauthsRecord
	_mfas: MfasRecord
	_otps: OtpsRecord
	_superusers: SuperusersRecord
	attorney_coaches: AttorneyCoachesRecord
	attorney_tasks: AttorneyTasksRecord
	ballot_corrections: BallotCorrectionsRecord
	ballot_scores: BallotScoresRecord
	ballot_submissions: BallotSubmissionsRecord
	case_characters: CaseCharactersRecord
	co_coaches: CoCoachesRecord
	courtrooms: CourtroomsRecord
	districts: DistrictsRecord
	eligibility_change_requests: EligibilityChangeRequestsRecord
	eligibility_list_entries: EligibilityListEntriesRecord
	judges: JudgesRecord
	presider_ballots: PresiderBallotsRecord
	registrations: RegistrationsRecord
	roster_entries: RosterEntriesRecord
	roster_submissions: RosterSubmissionsRecord
	rounds: RoundsRecord
	schools: SchoolsRecord
	scorer_tokens: ScorerTokensRecord
	students: StudentsRecord
	teams: TeamsRecord
	tournaments: TournamentsRecord
	trials: TrialsRecord
	users: UsersRecord
	withdrawal_requests: WithdrawalRequestsRecord
}

export type CollectionResponses = {
	_authOrigins: AuthoriginsResponse
	_externalAuths: ExternalauthsResponse
	_mfas: MfasResponse
	_otps: OtpsResponse
	_superusers: SuperusersResponse
	attorney_coaches: AttorneyCoachesResponse
	attorney_tasks: AttorneyTasksResponse
	ballot_corrections: BallotCorrectionsResponse
	ballot_scores: BallotScoresResponse
	ballot_submissions: BallotSubmissionsResponse
	case_characters: CaseCharactersResponse
	co_coaches: CoCoachesResponse
	courtrooms: CourtroomsResponse
	districts: DistrictsResponse
	eligibility_change_requests: EligibilityChangeRequestsResponse
	eligibility_list_entries: EligibilityListEntriesResponse
	judges: JudgesResponse
	presider_ballots: PresiderBallotsResponse
	registrations: RegistrationsResponse
	roster_entries: RosterEntriesResponse
	roster_submissions: RosterSubmissionsResponse
	rounds: RoundsResponse
	schools: SchoolsResponse
	scorer_tokens: ScorerTokensResponse
	students: StudentsResponse
	teams: TeamsResponse
	tournaments: TournamentsResponse
	trials: TrialsResponse
	users: UsersResponse
	withdrawal_requests: WithdrawalRequestsResponse
}

// Utility types for create/update operations

type ProcessCreateAndUpdateFields<T> = Omit<{
	// Omit AutoDate fields
	[K in keyof T as Extract<T[K], IsoAutoDateString> extends never ? K : never]: 
		// Convert FileNameString to File
		T[K] extends infer U ? 
			U extends (FileNameString | FileNameString[]) ? 
				U extends any[] ? File[] : File 
			: U
		: never
}, 'id'>

// Create type for Auth collections
export type CreateAuth<T> = {
	id?: RecordIdString
	email: string
	emailVisibility?: boolean
	password: string
	passwordConfirm: string
	verified?: boolean
} & ProcessCreateAndUpdateFields<T>

// Create type for Base collections
export type CreateBase<T> = {
	id?: RecordIdString
} & ProcessCreateAndUpdateFields<T>

// Update type for Auth collections
export type UpdateAuth<T> = Partial<
	Omit<ProcessCreateAndUpdateFields<T>, keyof AuthSystemFields>
> & {
	email?: string
	emailVisibility?: boolean
	oldPassword?: string
	password?: string
	passwordConfirm?: string
	verified?: boolean
}

// Update type for Base collections
export type UpdateBase<T> = Partial<
	Omit<ProcessCreateAndUpdateFields<T>, keyof BaseSystemFields>
>

// Get the correct create type for any collection
export type Create<T extends keyof CollectionResponses> =
	CollectionResponses[T] extends AuthSystemFields
		? CreateAuth<CollectionRecords[T]>
		: CreateBase<CollectionRecords[T]>

// Get the correct update type for any collection
export type Update<T extends keyof CollectionResponses> =
	CollectionResponses[T] extends AuthSystemFields
		? UpdateAuth<CollectionRecords[T]>
		: UpdateBase<CollectionRecords[T]>

// Type for usage with type asserted PocketBase instance
// https://github.com/pocketbase/js-sdk#specify-typescript-definitions

export type TypedPocketBase = {
	collection<T extends keyof CollectionResponses>(
		idOrName: T
	): RecordService<CollectionResponses[T]>
} & PocketBase
