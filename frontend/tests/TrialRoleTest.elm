module TrialRoleTest exposing (suite)

import Error exposing (Error(..))
import Expect
import Test exposing (Test, describe, test)
import TrialRole exposing (TrialRole(..))


suite : Test
suite =
    describe "TrialRole"
        [ describe "toString / fromString round-trip"
            [ roundTrip ScorerRole "ScorerRole"
            , roundTrip PresiderRole "PresiderRole"
            ]
        , describe "fromString"
            [ test "rejects unknown string" <|
                \_ ->
                    TrialRole.fromString "Unknown"
                        |> Expect.equal
                            (Err [ Error "Unknown trial role: Unknown" ])
            ]
        , describe "all"
            [ test "contains every variant" <|
                \_ ->
                    TrialRole.all
                        |> Expect.equal
                            [ ScorerRole
                            , PresiderRole
                            ]
            ]
        ]


roundTrip : TrialRole -> String -> Test
roundTrip role str =
    describe (str ++ " round-trip")
        [ test "toString" <|
            \_ ->
                role
                    |> TrialRole.toString
                    |> Expect.equal str
        , test "fromString" <|
            \_ ->
                TrialRole.fromString str
                    |> Expect.equal (Ok role)
        ]
