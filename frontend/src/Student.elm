module Student exposing
    ( Name
    , Pronouns(..)
    , Student
    , create
    , displayName
    , first
    , fullName
    , last
    , nameFromStrings
    , preferred
    , pronouns
    , pronounsToString
    , studentName
    )

import Error exposing (Error(..))
import Validate


type Name
    = Name
        { first : String
        , last : String
        , preferred : Maybe String
        }


nameFromStrings :
    String
    -> String
    -> Maybe String
    -> Result (List Error) Name
nameFromStrings rawFirst rawLast rawPreferred =
    let
        trimmedFirst =
            String.trim rawFirst

        trimmedLast =
            String.trim rawLast

        trimmedPreferred =
            Maybe.map String.trim rawPreferred
                |> Maybe.andThen
                    (\s ->
                        if String.isEmpty s then
                            Nothing

                        else
                            Just s
                    )
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
                Name
                    { first = trimmedFirst
                    , last = trimmedLast
                    , preferred = trimmedPreferred
                    }
            )


first : Name -> String
first (Name r) =
    r.first


last : Name -> String
last (Name r) =
    r.last


preferred : Name -> Maybe String
preferred (Name r) =
    r.preferred


displayName : Name -> String
displayName (Name r) =
    Maybe.withDefault r.first r.preferred


fullName : Name -> String
fullName n =
    displayName n ++ " " ++ last n


type Pronouns
    = HeHim
    | SheHer
    | TheyThem
    | Other String


type Student
    = Student { name : Name, pronouns : Pronouns }


create : Name -> Pronouns -> Student
create n p =
    Student { name = n, pronouns = p }


studentName : Student -> Name
studentName (Student r) =
    r.name


pronouns : Student -> Pronouns
pronouns (Student r) =
    r.pronouns


pronounsToString : Pronouns -> String
pronounsToString p =
    case p of
        HeHim ->
            "he/him"

        SheHer ->
            "she/her"

        TheyThem ->
            "they/them"

        Other custom ->
            custom
