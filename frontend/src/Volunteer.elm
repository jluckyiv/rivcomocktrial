module Volunteer exposing
    ( Name
    , Volunteer
    , create
    , email
    , name
    , nameFromStrings
    , nameToString
    , role
    )

import Email exposing (Email)
import Error exposing (Error(..))
import TrialRole exposing (TrialRole)
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


type Volunteer
    = Volunteer { name : Name, email : Email, role : TrialRole }


create : Name -> Email -> TrialRole -> Volunteer
create n e r =
    Volunteer { name = n, email = e, role = r }


name : Volunteer -> Name
name (Volunteer r) =
    r.name


email : Volunteer -> Email
email (Volunteer r) =
    r.email


role : Volunteer -> TrialRole
role (Volunteer r) =
    r.role
