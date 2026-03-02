module TrialRole exposing
    ( TrialRole(..)
    , all
    , fromString
    , toString
    )

import Error exposing (Error(..))


type TrialRole
    = ScorerRole
    | PresiderRole


all : List TrialRole
all =
    [ ScorerRole
    , PresiderRole
    ]


toString : TrialRole -> String
toString role =
    case role of
        ScorerRole ->
            "ScorerRole"

        PresiderRole ->
            "PresiderRole"


fromString : String -> Result (List Error) TrialRole
fromString str =
    case str of
        "ScorerRole" ->
            Ok ScorerRole

        "PresiderRole" ->
            Ok PresiderRole

        _ ->
            Err [ Error ("Unknown trial role: " ++ str) ]
