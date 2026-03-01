module Pronouns exposing (Pronouns(..), toString)


type Pronouns
    = HeHim
    | SheHer
    | TheyThem
    | Other String


toString : Pronouns -> String
toString pronouns =
    case pronouns of
        HeHim ->
            "he/him"

        SheHer ->
            "she/her"

        TheyThem ->
            "they/them"

        Other custom ->
            custom
