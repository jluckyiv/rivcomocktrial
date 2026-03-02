module Judge exposing
    ( Judge
    , Name
    , create
    , email
    , name
    , nameFromStrings
    , nameToString
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


type Judge
    = Judge { name : Name, email : Email }


create : Name -> Email -> Judge
create n e =
    Judge { name = n, email = e }


name : Judge -> Name
name (Judge r) =
    r.name


email : Judge -> Email
email (Judge r) =
    r.email
