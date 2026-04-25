module Api exposing
    ( AttorneyCoach
    , AttorneyTask
    , BallotCorrection
    , BallotScore
    , BallotStatus(..)
    , BallotSubmission
    , CaseCharacter
    , ChangeRequest
    , ChangeType(..)
    , CoCoach
    , CoachUser
    , CoachUserStatus(..)
    , Courtroom
    , EligibilityEntry
    , EligibilityStatus
    , EntryType(..)
    , Judge
    , MotionRuling(..)
    , PresiderBallotRecord
    , PresentationType(..)
    , RequestStatus(..)
    , RosterEntry
    , RosterRole(..)
    , RosterSide(..)
    , RosterSubmission
    , Round
    , RoundStatus(..)
    , RoundType(..)
    , School
    , ScorerRole(..)
    , ScorerToken
    , Student
    , TaskType(..)
    , Team
    , TeamStatus(..)
    , TokenStatus(..)
    , Tournament
    , TournamentStatus(..)
    , Trial
    , TrialVerdict(..)
    , WithdrawalRequest
    , withdrawalRequestDecoder
    , attorneyCoachDecoder
    , attorneyTaskDecoder
    , ballotCorrectionDecoder
    , ballotScoreDecoder
    , ballotSubmissionDecoder
    , caseCharacterDecoder
    , changeRequestDecoder
    , coCoachDecoder
    , coachUserDecoder
    , courtroomDecoder
    , eligibilityEntryDecoder
    , encodeAttorneyCoach
    , encodeAttorneyTask
    , encodeBallotCorrection
    , encodeBallotScore
    , encodeBallotSubmission
    , encodeCaseCharacter
    , encodeChangeRequest
    , encodeCoCoach
    , encodeCoachRegistration
    , encodeCoachUserStatus
    , encodeCourtroom
    , encodeEligibilityEntry
    , encodeJudge
    , encodePresiderBallotRecord
    , encodePresentationType
    , encodeRequestStatus
    , encodeRosterEntry
    , encodeRosterSubmission
    , encodeRound
    , encodeRoundStatus
    , encodeScorerRole
    , encodeScorerToken
    , encodeSchool
    , encodeStudent
    , encodeTeam
    , encodeTeamStatus
    , encodeTournament
    , encodeTrial
    , encodeTrialAssignment
    , encodeWithdrawalRequest
    , judgeDecoder
    , presiderBallotRecordDecoder
    , rosterEntryDecoder
    , rosterSideToString
    , rosterSubmissionDecoder
    , roundDecoder
    , roundStatusToString
    , roundTypeToString
    , schoolDecoder
    , scorerTokenDecoder
    , studentDecoder
    , teamDecoder
    , tournamentDecoder
    , trialDecoder
    )

{-| PocketBase record types, decoders, and encoders.

All API operations go through the Pb module (port-based
PB JS SDK client). This module only defines data shapes.

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- TYPES


type TournamentStatus
    = TournamentDraft
    | TournamentRegistration
    | TournamentActive
    | TournamentCompleted


type TeamStatus
    = TeamPending
    | TeamActive
    | TeamWithdrawn
    | TeamRejected


type CoachUserStatus
    = CoachPending
    | CoachApproved
    | CoachRejected


type RoundType
    = Preliminary
    | Elimination


type RosterSide
    = Prosecution
    | Defense


type EntryType
    = ActiveEntry
    | SubstituteEntry
    | NonActiveEntry


type RosterRole
    = PretrialAttorneyRole
    | TrialAttorneyRole
    | WitnessRole
    | ClerkRole
    | BailiffRole
    | ArtistRole
    | JournalistRole


type TaskType
    = OpeningTask
    | DirectTask
    | CrossTask
    | ClosingTask


type alias Tournament =
    { id : String
    , name : String
    , year : Int
    , numPreliminaryRounds : Int
    , numEliminationRounds : Int
    , status : TournamentStatus
    , eligibilityLockedAt : Maybe String
    , rosterDeadlineHours : Maybe Int
    , created : String
    , updated : String
    }


type alias School =
    { id : String
    , name : String
    , district : String
    , created : String
    , updated : String
    }


type alias Team =
    { id : String
    , tournament : String
    , school : String
    , teamNumber : Int
    , name : String
    , status : TeamStatus
    , coach : String
    , created : String
    , updated : String
    }


type alias Student =
    { id : String
    , name : String
    , school : String
    , pronouns : Maybe String
    , created : String
    , updated : String
    }


type alias Courtroom =
    { id : String
    , name : String
    , location : String
    , created : String
    , updated : String
    }


type RoundStatus
    = Upcoming
    | Open
    | Locked


type alias Round =
    { id : String
    , number : Int
    , date : String
    , roundType : RoundType
    , published : Bool
    , tournament : String
    , status : RoundStatus
    , rankingMin : Maybe Int
    , rankingMax : Maybe Int
    , created : String
    , updated : String
    }


type alias Trial =
    { id : String
    , round : String
    , prosecutionTeam : String
    , defenseTeam : String
    , courtroom : String
    , judge : String
    , scorer1 : String
    , scorer2 : String
    , scorer3 : String
    , scorer4 : String
    , scorer5 : String
    , created : String
    , updated : String
    }


type alias Judge =
    { id : String
    , name : String
    , email : String
    , created : String
    , updated : String
    }


type MotionRuling
    = Granted
    | Denied


type TrialVerdict
    = Guilty
    | NotGuilty


type alias CoachUser =
    { id : String
    , email : String
    , name : String
    , school : String
    , teamName : String
    , status : CoachUserStatus
    , role : String
    , created : String
    , updated : String
    }


type ChangeType
    = AddStudent
    | RemoveStudent


type RequestStatus
    = Pending
    | Approved
    | Rejected


type EligibilityStatus
    = Active
    | Removed


type alias EligibilityEntry =
    { id : String
    , team : String
    , tournament : String
    , name : String
    , status : EligibilityStatus
    , created : String
    , updated : String
    }


type alias ChangeRequest =
    { id : String
    , team : String
    , studentName : String
    , changeType : ChangeType
    , notes : String
    , status : RequestStatus
    , created : String
    , updated : String
    }


type alias WithdrawalRequest =
    { id : String
    , team : String
    , reason : String
    , status : RequestStatus
    , created : String
    , updated : String
    }


type alias CoCoach =
    { id : String
    , team : String
    , name : String
    , email : String
    }


type alias AttorneyCoach =
    { id : String
    , team : String
    , name : String
    , contact : String
    }


type alias CaseCharacter =
    { id : String
    , tournament : String
    , side : RosterSide
    , characterName : String
    , description : String
    , sortOrder : Int
    , created : String
    , updated : String
    }


type alias RosterSubmission =
    { id : String
    , team : String
    , round : String
    , side : RosterSide
    , submittedAt : Maybe String
    , created : String
    , updated : String
    }


type alias RosterEntry =
    { id : String
    , team : String
    , round : String
    , side : RosterSide
    , student : Maybe String
    , entryType : EntryType
    , role : Maybe RosterRole
    , character : Maybe String
    , sortOrder : Maybe Int
    , created : String
    , updated : String
    }


type alias AttorneyTask =
    { id : String
    , rosterEntry : String
    , taskType : TaskType
    , character : Maybe String
    , sortOrder : Int
    , created : String
    , updated : String
    }


type ScorerRole
    = Scorer
    | Presider


type TokenStatus
    = TokenActive
    | TokenUsed
    | TokenRevoked


type alias ScorerToken =
    { id : String
    , trial : String
    , token : String
    , scorerName : Maybe String
    , scorerRole : ScorerRole
    , status : TokenStatus
    , created : String
    , updated : String
    }


type BallotStatus
    = BallotSubmitted
    | BallotVerified
    | BallotCorrected


type alias BallotSubmission =
    { id : String
    , scorerToken : String
    , trial : String
    , status : BallotStatus
    , submittedAt : String
    , created : String
    , updated : String
    }


type PresentationType
    = PretrialPresentation
    | OpeningPresentation
    | DirectExaminationPresentation
    | CrossExaminationPresentation
    | ClosingPresentation
    | WitnessExaminationPresentation
    | ClerkPerformancePresentation
    | BailiffPerformancePresentation


type alias BallotScore =
    { id : String
    , ballot : String
    , presentation : PresentationType
    , side : RosterSide
    , studentName : String
    , rosterEntry : Maybe String
    , points : Int
    , sortOrder : Int
    , created : String
    , updated : String
    }


type alias PresiderBallotRecord =
    { id : String
    , scorerToken : String
    , trial : String
    , winnerSide : RosterSide
    , motionRuling : Maybe MotionRuling
    , verdict : Maybe TrialVerdict
    , submittedAt : String
    , created : String
    , updated : String
    }


type alias BallotCorrection =
    { id : String
    , ballot : String
    , originalScoreId : String
    , correctedPoints : Int
    , reason : Maybe String
    , correctedAt : String
    , created : String
    , updated : String
    }



-- DECODERS


tournamentStatusDecoder : Decoder TournamentStatus
tournamentStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "draft" ->
                        Decode.succeed TournamentDraft

                    "registration" ->
                        Decode.succeed TournamentRegistration

                    "active" ->
                        Decode.succeed TournamentActive

                    "completed" ->
                        Decode.succeed TournamentCompleted

                    _ ->
                        Decode.fail ("Unknown tournament status: " ++ s)
            )


teamStatusDecoder : Decoder TeamStatus
teamStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "pending" ->
                        Decode.succeed TeamPending

                    "active" ->
                        Decode.succeed TeamActive

                    "withdrawn" ->
                        Decode.succeed TeamWithdrawn

                    "rejected" ->
                        Decode.succeed TeamRejected

                    _ ->
                        Decode.fail ("Unknown team status: " ++ s)
            )


coachUserStatusDecoder : Decoder CoachUserStatus
coachUserStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "pending" ->
                        Decode.succeed CoachPending

                    "approved" ->
                        Decode.succeed CoachApproved

                    "rejected" ->
                        Decode.succeed CoachRejected

                    _ ->
                        Decode.fail ("Unknown coach user status: " ++ s)
            )


roundTypeDecoder : Decoder RoundType
roundTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "preliminary" ->
                        Decode.succeed Preliminary

                    "elimination" ->
                        Decode.succeed Elimination

                    _ ->
                        Decode.fail ("Unknown round type: " ++ s)
            )


roundStatusDecoder : Decoder RoundStatus
roundStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "upcoming" ->
                        Decode.succeed Upcoming

                    "open" ->
                        Decode.succeed Open

                    "locked" ->
                        Decode.succeed Locked

                    _ ->
                        Decode.fail ("Unknown round status: " ++ s)
            )


motionRulingDecoder : Decoder MotionRuling
motionRulingDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "granted" ->
                        Decode.succeed Granted

                    "denied" ->
                        Decode.succeed Denied

                    _ ->
                        Decode.fail ("Unknown motion ruling: " ++ s)
            )


trialVerdictDecoder : Decoder TrialVerdict
trialVerdictDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "guilty" ->
                        Decode.succeed Guilty

                    "not_guilty" ->
                        Decode.succeed NotGuilty

                    _ ->
                        Decode.fail ("Unknown trial verdict: " ++ s)
            )


judgeDecoder : Decoder Judge
judgeDecoder =
    Decode.succeed Judge
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (fieldWithDefault "email" Decode.string "")
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


rosterSideDecoder : Decoder RosterSide
rosterSideDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "prosecution" ->
                        Decode.succeed Prosecution

                    "defense" ->
                        Decode.succeed Defense

                    _ ->
                        Decode.fail ("Unknown roster side: " ++ s)
            )


entryTypeDecoder : Decoder EntryType
entryTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "active" ->
                        Decode.succeed ActiveEntry

                    "substitute" ->
                        Decode.succeed SubstituteEntry

                    "non_active" ->
                        Decode.succeed NonActiveEntry

                    _ ->
                        Decode.fail ("Unknown entry type: " ++ s)
            )


rosterRoleDecoder : Decoder RosterRole
rosterRoleDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "pretrial_attorney" ->
                        Decode.succeed PretrialAttorneyRole

                    "trial_attorney" ->
                        Decode.succeed TrialAttorneyRole

                    "witness" ->
                        Decode.succeed WitnessRole

                    "clerk" ->
                        Decode.succeed ClerkRole

                    "bailiff" ->
                        Decode.succeed BailiffRole

                    "artist" ->
                        Decode.succeed ArtistRole

                    "journalist" ->
                        Decode.succeed JournalistRole

                    _ ->
                        Decode.fail ("Unknown roster role: " ++ s)
            )


taskTypeDecoder : Decoder TaskType
taskTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "opening" ->
                        Decode.succeed OpeningTask

                    "direct" ->
                        Decode.succeed DirectTask

                    "cross" ->
                        Decode.succeed CrossTask

                    "closing" ->
                        Decode.succeed ClosingTask

                    _ ->
                        Decode.fail ("Unknown task type: " ++ s)
            )


tournamentDecoder : Decoder Tournament
tournamentDecoder =
    Decode.succeed Tournament
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "year" Decode.int)
        |> andMap (Decode.field "num_preliminary_rounds" Decode.int)
        |> andMap (Decode.field "num_elimination_rounds" Decode.int)
        |> andMap (Decode.field "status" tournamentStatusDecoder)
        |> andMap
            (fieldWithDefault "eligibility_locked_at"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap
            (fieldWithDefault "roster_deadline_hours"
                (Decode.nullable Decode.int)
                Nothing
            )
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


schoolDecoder : Decoder School
schoolDecoder =
    Decode.map5 School
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "district" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


teamDecoder : Decoder Team
teamDecoder =
    Decode.succeed Team
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "tournament" Decode.string)
        |> andMap (Decode.field "school" Decode.string)
        |> andMap (fieldWithDefault "team_number" Decode.int 0)
        |> andMap (fieldWithDefault "name" Decode.string "")
        |> andMap (fieldWithDefault "status" teamStatusDecoder TeamPending)
        |> andMap (fieldWithDefault "coach" Decode.string "")
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


studentDecoder : Decoder Student
studentDecoder =
    Decode.succeed Student
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "school" Decode.string)
        |> andMap
            (fieldWithDefault "pronouns"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


courtroomDecoder : Decoder Courtroom
courtroomDecoder =
    Decode.map5 Courtroom
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "location" Decode.string "")
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


roundDecoder : Decoder Round
roundDecoder =
    Decode.succeed Round
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "number" Decode.int)
        |> andMap (fieldWithDefault "date" Decode.string "")
        |> andMap (Decode.field "type" roundTypeDecoder)
        |> andMap (fieldWithDefault "published" Decode.bool False)
        |> andMap (Decode.field "tournament" Decode.string)
        |> andMap (Decode.field "status" roundStatusDecoder)
        |> andMap (fieldWithDefault "ranking_min" (Decode.nullable Decode.int) Nothing)
        |> andMap (fieldWithDefault "ranking_max" (Decode.nullable Decode.int) Nothing)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


trialDecoder : Decoder Trial
trialDecoder =
    Decode.succeed Trial
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "round" Decode.string)
        |> andMap (Decode.field "prosecution_team" Decode.string)
        |> andMap (Decode.field "defense_team" Decode.string)
        |> andMap (fieldWithDefault "courtroom" Decode.string "")
        |> andMap (fieldWithDefault "judge" Decode.string "")
        |> andMap (fieldWithDefault "scorer_1" Decode.string "")
        |> andMap (fieldWithDefault "scorer_2" Decode.string "")
        |> andMap (fieldWithDefault "scorer_3" Decode.string "")
        |> andMap (fieldWithDefault "scorer_4" Decode.string "")
        |> andMap (fieldWithDefault "scorer_5" Decode.string "")
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


coachUserDecoder : Decoder CoachUser
coachUserDecoder =
    Decode.succeed CoachUser
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (fieldWithDefault "email" Decode.string "")
        |> andMap (fieldWithDefault "name" Decode.string "")
        |> andMap (fieldWithDefault "school" Decode.string "")
        |> andMap (fieldWithDefault "team_name" Decode.string "")
        |> andMap (fieldWithDefault "status" coachUserStatusDecoder CoachPending)
        |> andMap (fieldWithDefault "role" Decode.string "")
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


changeTypeDecoder : Decoder ChangeType
changeTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "add" ->
                        Decode.succeed AddStudent

                    "remove" ->
                        Decode.succeed RemoveStudent

                    _ ->
                        Decode.fail ("Unknown change type: " ++ s)
            )


requestStatusDecoder : Decoder RequestStatus
requestStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "pending" ->
                        Decode.succeed Pending

                    "approved" ->
                        Decode.succeed Approved

                    "rejected" ->
                        Decode.succeed Rejected

                    _ ->
                        Decode.fail ("Unknown request status: " ++ s)
            )


eligibilityStatusDecoder : Decoder EligibilityStatus
eligibilityStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "active" ->
                        Decode.succeed Active

                    "removed" ->
                        Decode.succeed Removed

                    _ ->
                        Decode.fail ("Unknown eligibility status: " ++ s)
            )


eligibilityEntryDecoder : Decoder EligibilityEntry
eligibilityEntryDecoder =
    Decode.map7 EligibilityEntry
        (Decode.field "id" Decode.string)
        (Decode.field "team" Decode.string)
        (Decode.field "tournament" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "status" eligibilityStatusDecoder)
        (Decode.field "created" Decode.string)
        (Decode.field "updated" Decode.string)


changeRequestDecoder : Decoder ChangeRequest
changeRequestDecoder =
    Decode.succeed ChangeRequest
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "team" Decode.string)
        |> andMap (Decode.field "student_name" Decode.string)
        |> andMap (Decode.field "change_type" changeTypeDecoder)
        |> andMap (fieldWithDefault "notes" Decode.string "")
        |> andMap (Decode.field "status" requestStatusDecoder)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


withdrawalRequestDecoder : Decoder WithdrawalRequest
withdrawalRequestDecoder =
    Decode.succeed WithdrawalRequest
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "team" Decode.string)
        |> andMap (fieldWithDefault "reason" Decode.string "")
        |> andMap (Decode.field "status" requestStatusDecoder)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


coCoachDecoder : Decoder CoCoach
coCoachDecoder =
    Decode.map4 CoCoach
        (Decode.field "id" Decode.string)
        (Decode.field "team" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "email" Decode.string "")


attorneyCoachDecoder : Decoder AttorneyCoach
attorneyCoachDecoder =
    Decode.map4 AttorneyCoach
        (Decode.field "id" Decode.string)
        (Decode.field "team" Decode.string)
        (Decode.field "name" Decode.string)
        (fieldWithDefault "contact" Decode.string "")


caseCharacterDecoder : Decoder CaseCharacter
caseCharacterDecoder =
    Decode.succeed CaseCharacter
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "tournament" Decode.string)
        |> andMap (Decode.field "side" rosterSideDecoder)
        |> andMap (Decode.field "character_name" Decode.string)
        |> andMap (fieldWithDefault "description" Decode.string "")
        |> andMap (fieldWithDefault "sort_order" Decode.int 0)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


rosterSubmissionDecoder : Decoder RosterSubmission
rosterSubmissionDecoder =
    Decode.succeed RosterSubmission
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "team" Decode.string)
        |> andMap (Decode.field "round" Decode.string)
        |> andMap (fieldWithDefault "side" rosterSideDecoder Prosecution)
        |> andMap
            (fieldWithDefault "submitted_at"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


rosterEntryDecoder : Decoder RosterEntry
rosterEntryDecoder =
    Decode.succeed RosterEntry
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "team" Decode.string)
        |> andMap (Decode.field "round" Decode.string)
        |> andMap (Decode.field "side" rosterSideDecoder)
        |> andMap
            (fieldWithDefault "student"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "entry_type" entryTypeDecoder)
        |> andMap
            (fieldWithDefault "role"
                (Decode.nullable rosterRoleDecoder)
                Nothing
            )
        |> andMap
            (fieldWithDefault "character"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap
            (fieldWithDefault "sort_order"
                (Decode.nullable Decode.int)
                Nothing
            )
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


attorneyTaskDecoder : Decoder AttorneyTask
attorneyTaskDecoder =
    Decode.succeed AttorneyTask
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "roster_entry" Decode.string)
        |> andMap (Decode.field "task_type" taskTypeDecoder)
        |> andMap
            (fieldWithDefault "character"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (fieldWithDefault "sort_order" Decode.int 0)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


scorerRoleDecoder : Decoder ScorerRole
scorerRoleDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "scorer" ->
                        Decode.succeed Scorer

                    "presider" ->
                        Decode.succeed Presider

                    _ ->
                        Decode.fail ("Unknown scorer role: " ++ s)
            )


tokenStatusDecoder : Decoder TokenStatus
tokenStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "active" ->
                        Decode.succeed TokenActive

                    "used" ->
                        Decode.succeed TokenUsed

                    "revoked" ->
                        Decode.succeed TokenRevoked

                    _ ->
                        Decode.fail ("Unknown token status: " ++ s)
            )


scorerTokenDecoder : Decoder ScorerToken
scorerTokenDecoder =
    Decode.succeed ScorerToken
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "trial" Decode.string)
        |> andMap (Decode.field "token" Decode.string)
        |> andMap
            (fieldWithDefault "scorer_name"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "scorer_role" scorerRoleDecoder)
        |> andMap (Decode.field "status" tokenStatusDecoder)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


ballotStatusDecoder : Decoder BallotStatus
ballotStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "submitted" ->
                        Decode.succeed BallotSubmitted

                    "verified" ->
                        Decode.succeed BallotVerified

                    "corrected" ->
                        Decode.succeed BallotCorrected

                    _ ->
                        Decode.fail ("Unknown ballot status: " ++ s)
            )


ballotSubmissionDecoder : Decoder BallotSubmission
ballotSubmissionDecoder =
    Decode.succeed BallotSubmission
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "scorer_token" Decode.string)
        |> andMap (Decode.field "trial" Decode.string)
        |> andMap (Decode.field "status" ballotStatusDecoder)
        |> andMap (Decode.field "submitted_at" Decode.string)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


presentationTypeDecoder : Decoder PresentationType
presentationTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "pretrial" ->
                        Decode.succeed PretrialPresentation

                    "opening" ->
                        Decode.succeed OpeningPresentation

                    "direct_examination" ->
                        Decode.succeed DirectExaminationPresentation

                    "cross_examination" ->
                        Decode.succeed CrossExaminationPresentation

                    "closing" ->
                        Decode.succeed ClosingPresentation

                    "witness_examination" ->
                        Decode.succeed WitnessExaminationPresentation

                    "clerk_performance" ->
                        Decode.succeed ClerkPerformancePresentation

                    "bailiff_performance" ->
                        Decode.succeed BailiffPerformancePresentation

                    _ ->
                        Decode.fail ("Unknown presentation type: " ++ s)
            )


ballotScoreDecoder : Decoder BallotScore
ballotScoreDecoder =
    Decode.succeed BallotScore
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "ballot" Decode.string)
        |> andMap (Decode.field "presentation" presentationTypeDecoder)
        |> andMap (Decode.field "side" rosterSideDecoder)
        |> andMap (fieldWithDefault "student_name" Decode.string "")
        |> andMap
            (fieldWithDefault "roster_entry"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "points" Decode.int)
        |> andMap (fieldWithDefault "sort_order" Decode.int 0)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


presiderBallotRecordDecoder : Decoder PresiderBallotRecord
presiderBallotRecordDecoder =
    Decode.succeed PresiderBallotRecord
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "scorer_token" Decode.string)
        |> andMap (Decode.field "trial" Decode.string)
        |> andMap (Decode.field "winner_side" rosterSideDecoder)
        |> andMap (fieldWithDefault "motion_ruling" (Decode.nullable motionRulingDecoder) Nothing)
        |> andMap (fieldWithDefault "verdict" (Decode.nullable trialVerdictDecoder) Nothing)
        |> andMap (Decode.field "submitted_at" Decode.string)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)


ballotCorrectionDecoder : Decoder BallotCorrection
ballotCorrectionDecoder =
    Decode.succeed BallotCorrection
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "ballot" Decode.string)
        |> andMap (Decode.field "original_score" Decode.string)
        |> andMap (Decode.field "corrected_points" Decode.int)
        |> andMap
            (fieldWithDefault "reason"
                (Decode.nullable Decode.string)
                Nothing
            )
        |> andMap (Decode.field "corrected_at" Decode.string)
        |> andMap (Decode.field "created" Decode.string)
        |> andMap (Decode.field "updated" Decode.string)



-- ENCODERS


encodeTournamentStatus : TournamentStatus -> Encode.Value
encodeTournamentStatus s =
    case s of
        TournamentDraft ->
            Encode.string "draft"

        TournamentRegistration ->
            Encode.string "registration"

        TournamentActive ->
            Encode.string "active"

        TournamentCompleted ->
            Encode.string "completed"


encodeCoachUserStatus : CoachUserStatus -> Encode.Value
encodeCoachUserStatus s =
    case s of
        CoachPending ->
            Encode.string "pending"

        CoachApproved ->
            Encode.string "approved"

        CoachRejected ->
            Encode.string "rejected"


encodeRoundType : RoundType -> Encode.Value
encodeRoundType rt =
    case rt of
        Preliminary ->
            Encode.string "preliminary"

        Elimination ->
            Encode.string "elimination"


encodeRosterSide : RosterSide -> Encode.Value
encodeRosterSide s =
    case s of
        Prosecution ->
            Encode.string "prosecution"

        Defense ->
            Encode.string "defense"


encodeEntryType : EntryType -> Encode.Value
encodeEntryType et =
    case et of
        ActiveEntry ->
            Encode.string "active"

        SubstituteEntry ->
            Encode.string "substitute"

        NonActiveEntry ->
            Encode.string "non_active"


encodeRosterRole : RosterRole -> Encode.Value
encodeRosterRole rr =
    case rr of
        PretrialAttorneyRole ->
            Encode.string "pretrial_attorney"

        TrialAttorneyRole ->
            Encode.string "trial_attorney"

        WitnessRole ->
            Encode.string "witness"

        ClerkRole ->
            Encode.string "clerk"

        BailiffRole ->
            Encode.string "bailiff"

        ArtistRole ->
            Encode.string "artist"

        JournalistRole ->
            Encode.string "journalist"


encodeTournament :
    { name : String
    , year : Int
    , numPreliminaryRounds : Int
    , numEliminationRounds : Int
    , status : TournamentStatus
    }
    -> Encode.Value
encodeTournament t =
    Encode.object
        [ ( "name", Encode.string t.name )
        , ( "year", Encode.int t.year )
        , ( "num_preliminary_rounds", Encode.int t.numPreliminaryRounds )
        , ( "num_elimination_rounds", Encode.int t.numEliminationRounds )
        , ( "status", encodeTournamentStatus t.status )
        ]


encodeSchool :
    { name : String, district : String }
    -> Encode.Value
encodeSchool s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "district", Encode.string s.district )
        ]


encodeTeam :
    { tournament : String, school : String, teamNumber : Int, name : String }
    -> Encode.Value
encodeTeam t =
    Encode.object
        [ ( "tournament", Encode.string t.tournament )
        , ( "school", Encode.string t.school )
        , ( "team_number", Encode.int t.teamNumber )
        , ( "name", Encode.string t.name )
        ]


encodeStudent :
    { name : String, school : String, pronouns : Maybe String }
    -> Encode.Value
encodeStudent s =
    Encode.object
        [ ( "name", Encode.string s.name )
        , ( "school", Encode.string s.school )
        , ( "pronouns"
          , Maybe.map Encode.string s.pronouns
                |> Maybe.withDefault Encode.null
          )
        ]


encodeCourtroom :
    { name : String, location : String }
    -> Encode.Value
encodeCourtroom c =
    Encode.object
        [ ( "name", Encode.string c.name )
        , ( "location", Encode.string c.location )
        ]


encodeRound :
    { number : Int
    , date : String
    , roundType : RoundType
    , published : Bool
    , tournament : String
    }
    -> Encode.Value
encodeRound r =
    Encode.object
        [ ( "number", Encode.int r.number )
        , ( "date", Encode.string r.date )
        , ( "type", encodeRoundType r.roundType )
        , ( "published", Encode.bool r.published )
        , ( "tournament", Encode.string r.tournament )
        ]


encodeTrial :
    { round : String
    , prosecutionTeam : String
    , defenseTeam : String
    , courtroom : String
    }
    -> Encode.Value
encodeTrial t =
    Encode.object
        [ ( "round", Encode.string t.round )
        , ( "prosecution_team", Encode.string t.prosecutionTeam )
        , ( "defense_team", Encode.string t.defenseTeam )
        , ( "courtroom", Encode.string t.courtroom )
        ]


encodeTrialAssignment :
    { judge : String
    , scorer1 : String
    , scorer2 : String
    , scorer3 : String
    , scorer4 : String
    , scorer5 : String
    }
    -> Encode.Value
encodeTrialAssignment t =
    Encode.object
        [ ( "judge", Encode.string t.judge )
        , ( "scorer_1", Encode.string t.scorer1 )
        , ( "scorer_2", Encode.string t.scorer2 )
        , ( "scorer_3", Encode.string t.scorer3 )
        , ( "scorer_4", Encode.string t.scorer4 )
        , ( "scorer_5", Encode.string t.scorer5 )
        ]


encodeJudge :
    { name : String, email : String }
    -> Encode.Value
encodeJudge j =
    Encode.object
        [ ( "name", Encode.string j.name )
        , ( "email", Encode.string j.email )
        ]


encodeRoundStatus : RoundStatus -> Encode.Value
encodeRoundStatus s =
    Encode.string (roundStatusToString s)


encodeCoachRegistration :
    { email : String
    , password : String
    , passwordConfirm : String
    , name : String
    , school : String
    , teamName : String
    }
    -> Encode.Value
encodeCoachRegistration r =
    Encode.object
        [ ( "email", Encode.string r.email )
        , ( "password", Encode.string r.password )
        , ( "passwordConfirm", Encode.string r.passwordConfirm )
        , ( "name", Encode.string r.name )
        , ( "school", Encode.string r.school )
        , ( "team_name", Encode.string r.teamName )
        , ( "status", Encode.string "pending" )
        , ( "role", Encode.string "coach" )
        ]


encodeEligibilityEntry :
    { team : String, tournament : String, name : String }
    -> Encode.Value
encodeEligibilityEntry e =
    Encode.object
        [ ( "team", Encode.string e.team )
        , ( "tournament", Encode.string e.tournament )
        , ( "name", Encode.string e.name )
        , ( "status", Encode.string "active" )
        ]


encodeChangeType : ChangeType -> Encode.Value
encodeChangeType ct =
    case ct of
        AddStudent ->
            Encode.string "add"

        RemoveStudent ->
            Encode.string "remove"


encodeRequestStatus : RequestStatus -> Encode.Value
encodeRequestStatus rs =
    case rs of
        Pending ->
            Encode.string "pending"

        Approved ->
            Encode.string "approved"

        Rejected ->
            Encode.string "rejected"


encodeTeamStatus : TeamStatus -> Encode.Value
encodeTeamStatus s =
    case s of
        TeamPending ->
            Encode.string "pending"

        TeamActive ->
            Encode.string "active"

        TeamWithdrawn ->
            Encode.string "withdrawn"

        TeamRejected ->
            Encode.string "rejected"


encodeWithdrawalRequest :
    { team : String, reason : String }
    -> Encode.Value
encodeWithdrawalRequest r =
    Encode.object
        [ ( "team", Encode.string r.team )
        , ( "reason", Encode.string r.reason )
        , ( "status", encodeRequestStatus Pending )
        ]


encodeChangeRequest :
    { team : String
    , studentName : String
    , changeType : ChangeType
    , notes : String
    }
    -> Encode.Value
encodeChangeRequest r =
    Encode.object
        [ ( "team", Encode.string r.team )
        , ( "student_name", Encode.string r.studentName )
        , ( "change_type", encodeChangeType r.changeType )
        , ( "notes", Encode.string r.notes )
        , ( "status", encodeRequestStatus Pending )
        ]


encodeCoCoach :
    { team : String, name : String, email : String }
    -> Encode.Value
encodeCoCoach c =
    Encode.object
        [ ( "team", Encode.string c.team )
        , ( "name", Encode.string c.name )
        , ( "email", Encode.string c.email )
        ]


encodeAttorneyCoach :
    { team : String, name : String, contact : String }
    -> Encode.Value
encodeAttorneyCoach c =
    Encode.object
        [ ( "team", Encode.string c.team )
        , ( "name", Encode.string c.name )
        , ( "contact", Encode.string c.contact )
        ]


encodeCaseCharacter :
    { tournament : String
    , side : RosterSide
    , characterName : String
    , description : String
    , sortOrder : Int
    }
    -> Encode.Value
encodeCaseCharacter c =
    Encode.object
        [ ( "tournament", Encode.string c.tournament )
        , ( "side", encodeRosterSide c.side )
        , ( "character_name", Encode.string c.characterName )
        , ( "description", Encode.string c.description )
        , ( "sort_order", Encode.int c.sortOrder )
        ]


encodeRosterSubmission :
    { team : String
    , round : String
    , side : RosterSide
    , submittedAt : Maybe String
    }
    -> Encode.Value
encodeRosterSubmission s =
    Encode.object
        [ ( "team", Encode.string s.team )
        , ( "round", Encode.string s.round )
        , ( "side", encodeRosterSide s.side )
        , ( "submitted_at"
          , Maybe.map Encode.string s.submittedAt
                |> Maybe.withDefault Encode.null
          )
        ]


encodeRosterEntry :
    { team : String
    , round : String
    , side : RosterSide
    , student : Maybe String
    , entryType : EntryType
    , role : Maybe RosterRole
    , character : Maybe String
    , sortOrder : Maybe Int
    }
    -> Encode.Value
encodeRosterEntry e =
    Encode.object
        [ ( "team", Encode.string e.team )
        , ( "round", Encode.string e.round )
        , ( "side", encodeRosterSide e.side )
        , ( "student"
          , Maybe.map Encode.string e.student
                |> Maybe.withDefault Encode.null
          )
        , ( "entry_type", encodeEntryType e.entryType )
        , ( "role"
          , Maybe.map encodeRosterRole e.role
                |> Maybe.withDefault Encode.null
          )
        , ( "character"
          , Maybe.map Encode.string e.character
                |> Maybe.withDefault Encode.null
          )
        , ( "sort_order"
          , Maybe.map Encode.int e.sortOrder
                |> Maybe.withDefault Encode.null
          )
        ]



encodeTaskType : TaskType -> Encode.Value
encodeTaskType tt =
    case tt of
        OpeningTask ->
            Encode.string "opening"

        DirectTask ->
            Encode.string "direct"

        CrossTask ->
            Encode.string "cross"

        ClosingTask ->
            Encode.string "closing"


encodeAttorneyTask :
    { rosterEntry : String
    , taskType : TaskType
    , character : Maybe String
    , sortOrder : Int
    }
    -> Encode.Value
encodeAttorneyTask t =
    Encode.object
        [ ( "roster_entry", Encode.string t.rosterEntry )
        , ( "task_type", encodeTaskType t.taskType )
        , ( "character"
          , Maybe.map Encode.string t.character
                |> Maybe.withDefault Encode.null
          )
        , ( "sort_order", Encode.int t.sortOrder )
        ]


encodeScorerRole : ScorerRole -> Encode.Value
encodeScorerRole r =
    case r of
        Scorer ->
            Encode.string "scorer"

        Presider ->
            Encode.string "presider"


encodeTokenStatus : TokenStatus -> Encode.Value
encodeTokenStatus s =
    case s of
        TokenActive ->
            Encode.string "active"

        TokenUsed ->
            Encode.string "used"

        TokenRevoked ->
            Encode.string "revoked"


encodeScorerToken :
    { trial : String
    , token : String
    , scorerRole : ScorerRole
    }
    -> Encode.Value
encodeScorerToken t =
    Encode.object
        [ ( "trial", Encode.string t.trial )
        , ( "token", Encode.string t.token )
        , ( "scorer_role", encodeScorerRole t.scorerRole )
        , ( "status", encodeTokenStatus TokenActive )
        ]


encodeBallotStatus : BallotStatus -> Encode.Value
encodeBallotStatus s =
    case s of
        BallotSubmitted ->
            Encode.string "submitted"

        BallotVerified ->
            Encode.string "verified"

        BallotCorrected ->
            Encode.string "corrected"


encodeBallotSubmission :
    { scorerToken : String
    , trial : String
    , submittedAt : String
    }
    -> Encode.Value
encodeBallotSubmission b =
    Encode.object
        [ ( "scorer_token", Encode.string b.scorerToken )
        , ( "trial", Encode.string b.trial )
        , ( "status", encodeBallotStatus BallotSubmitted )
        , ( "submitted_at", Encode.string b.submittedAt )
        ]


encodePresentationType : PresentationType -> Encode.Value
encodePresentationType p =
    case p of
        PretrialPresentation ->
            Encode.string "pretrial"

        OpeningPresentation ->
            Encode.string "opening"

        DirectExaminationPresentation ->
            Encode.string "direct_examination"

        CrossExaminationPresentation ->
            Encode.string "cross_examination"

        ClosingPresentation ->
            Encode.string "closing"

        WitnessExaminationPresentation ->
            Encode.string "witness_examination"

        ClerkPerformancePresentation ->
            Encode.string "clerk_performance"

        BailiffPerformancePresentation ->
            Encode.string "bailiff_performance"


encodeBallotScore :
    { ballot : String
    , presentation : PresentationType
    , side : RosterSide
    , studentName : String
    , rosterEntry : Maybe String
    , points : Int
    , sortOrder : Int
    }
    -> Encode.Value
encodeBallotScore s =
    Encode.object
        [ ( "ballot", Encode.string s.ballot )
        , ( "presentation", encodePresentationType s.presentation )
        , ( "side", encodeRosterSide s.side )
        , ( "student_name", Encode.string s.studentName )
        , ( "roster_entry"
          , Maybe.map Encode.string s.rosterEntry
                |> Maybe.withDefault Encode.null
          )
        , ( "points", Encode.int s.points )
        , ( "sort_order", Encode.int s.sortOrder )
        ]


encodePresiderBallotRecord :
    { scorerToken : String
    , trial : String
    , winnerSide : RosterSide
    , submittedAt : String
    }
    -> Encode.Value
encodePresiderBallotRecord b =
    Encode.object
        [ ( "scorer_token", Encode.string b.scorerToken )
        , ( "trial", Encode.string b.trial )
        , ( "winner_side", encodeRosterSide b.winnerSide )
        , ( "submitted_at", Encode.string b.submittedAt )
        ]


encodeBallotCorrection :
    { ballot : String
    , originalScore : String
    , correctedPoints : Int
    , reason : Maybe String
    , correctedAt : String
    }
    -> Encode.Value
encodeBallotCorrection c =
    Encode.object
        [ ( "ballot", Encode.string c.ballot )
        , ( "original_score", Encode.string c.originalScore )
        , ( "corrected_points", Encode.int c.correctedPoints )
        , ( "reason"
          , Maybe.map Encode.string c.reason
                |> Maybe.withDefault Encode.null
          )
        , ( "corrected_at", Encode.string c.correctedAt )
        ]



-- HELPERS


roundTypeToString : RoundType -> String
roundTypeToString rt =
    case rt of
        Preliminary ->
            "preliminary"

        Elimination ->
            "elimination"


roundStatusToString : RoundStatus -> String
roundStatusToString s =
    case s of
        Upcoming ->
            "upcoming"

        Open ->
            "open"

        Locked ->
            "locked"


rosterSideToString : RosterSide -> String
rosterSideToString s =
    case s of
        Prosecution ->
            "prosecution"

        Defense ->
            "defense"


fieldWithDefault :
    String
    -> Decoder a
    -> a
    -> Decoder a
fieldWithDefault name dec default =
    Decode.oneOf
        [ Decode.field name dec
        , Decode.succeed default
        ]


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)
