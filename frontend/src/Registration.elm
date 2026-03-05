module Registration exposing
    ( Registration
    , RegistrationId
    , Status(..)
    , approve
    , applicant
    , create
    , id
    , idFromString
    , idToString
    , reject
    , school
    , statusToString
    , teamName
    , status
    )

import Coach exposing (TeacherCoachApplicant)
import School exposing (School)
import Team


type Registration
    = Registration
        { id : RegistrationId
        , applicant : TeacherCoachApplicant
        , school : School
        , teamName : Team.Name
        , status : Status
        }


type RegistrationId
    = RegistrationId String


type Status
    = Pending
    | Approved
    | Rejected


create :
    RegistrationId
    -> TeacherCoachApplicant
    -> School
    -> Team.Name
    -> Registration
create regId regApplicant regSchool regTeamName =
    Registration
        { id = regId
        , applicant = regApplicant
        , school = regSchool
        , teamName = regTeamName
        , status = Pending
        }


approve : Registration -> Registration
approve (Registration reg) =
    case reg.status of
        Pending ->
            Registration { reg | status = Approved }

        _ ->
            Registration reg


reject : Registration -> Registration
reject (Registration reg) =
    case reg.status of
        Pending ->
            Registration { reg | status = Rejected }

        _ ->
            Registration reg


id : Registration -> RegistrationId
id (Registration reg) =
    reg.id


applicant : Registration -> TeacherCoachApplicant
applicant (Registration reg) =
    reg.applicant


school : Registration -> School
school (Registration reg) =
    reg.school


teamName : Registration -> Team.Name
teamName (Registration reg) =
    reg.teamName


status : Registration -> Status
status (Registration reg) =
    reg.status


idFromString : String -> RegistrationId
idFromString =
    RegistrationId


idToString : RegistrationId -> String
idToString (RegistrationId s) =
    s


statusToString : Status -> String
statusToString s =
    case s of
        Pending ->
            "Pending"

        Approved ->
            "Approved"

        Rejected ->
            "Rejected"
