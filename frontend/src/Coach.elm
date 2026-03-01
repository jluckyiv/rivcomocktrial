module Coach exposing
    ( AttorneyCoach
    , Name
    , TeacherCoach
    , TeacherCoachApplicant
    , apply
    , attorneyCoachEmail
    , attorneyCoachName
    , createAttorneyCoach
    , nameFromStrings
    , nameToString
    , teacherCoachApplicantEmail
    , teacherCoachApplicantName
    , teacherCoachEmail
    , teacherCoachName
    , verify
    )

import Email exposing (Email)
import Error exposing (Error(..))
import Validate


type Name
    = Name { first : String, last : String }


nameFromStrings : String -> String -> Result (List Error) Name
nameFromStrings first last =
    let
        trimmedFirst =
            String.trim first

        trimmedLast =
            String.trim last
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank Tuple.first
                (Error "First name cannot be blank")
            , Validate.ifBlank Tuple.second
                (Error "Last name cannot be blank")
            ]
        )
        ( trimmedFirst, trimmedLast )
        |> Result.map
            (\_ ->
                Name { first = trimmedFirst, last = trimmedLast }
            )


nameToString : Name -> String
nameToString (Name r) =
    r.first ++ " " ++ r.last


type TeacherCoachApplicant
    = TeacherCoachApplicant { name : Name, email : Email }


apply : Name -> Email -> TeacherCoachApplicant
apply name email =
    TeacherCoachApplicant { name = name, email = email }


teacherCoachApplicantName : TeacherCoachApplicant -> Name
teacherCoachApplicantName (TeacherCoachApplicant r) =
    r.name


teacherCoachApplicantEmail : TeacherCoachApplicant -> Email
teacherCoachApplicantEmail (TeacherCoachApplicant r) =
    r.email


type TeacherCoach
    = TeacherCoach { name : Name, email : Email }


verify : TeacherCoachApplicant -> TeacherCoach
verify (TeacherCoachApplicant r) =
    TeacherCoach { name = r.name, email = r.email }


teacherCoachName : TeacherCoach -> Name
teacherCoachName (TeacherCoach r) =
    r.name


teacherCoachEmail : TeacherCoach -> Email
teacherCoachEmail (TeacherCoach r) =
    r.email


type AttorneyCoach
    = AttorneyCoach { name : Name, email : Maybe Email }


createAttorneyCoach : Name -> Maybe Email -> AttorneyCoach
createAttorneyCoach name email =
    AttorneyCoach { name = name, email = email }


attorneyCoachName : AttorneyCoach -> Name
attorneyCoachName (AttorneyCoach r) =
    r.name


attorneyCoachEmail : AttorneyCoach -> Maybe Email
attorneyCoachEmail (AttorneyCoach r) =
    r.email
