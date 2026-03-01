module TrialTest exposing (suite)

import Assignment exposing (Assignment(..))
import Courtroom
import Expect
import Judge exposing (Judge(..))
import Pairing
import Test exposing (Test, describe, test)
import TestHelpers exposing (teamA, teamB)
import Trial


courtroom : Courtroom.Courtroom
courtroom =
    { name = Courtroom.name "Dept 1" }


suite : Test
suite =
    describe "Trial"
        [ describe "fromPairing"
            [ test "nothing assigned returns Nothing" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "only courtroom assigned returns Nothing" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Pairing.assignCourtroom courtroom
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "only judge assigned returns Nothing" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "both assigned returns Just Trial" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Expect.equal
                            (Just
                                { prosecution = teamA
                                , defense = teamB
                                , courtroom = courtroom
                                , judge = Judge
                                }
                            )
            ]
        ]
