module TrialTest exposing (suite)

import Assignment exposing (Assignment(..))
import Courtroom
import Expect
import Judge exposing (Judge(..))
import Pairing
import Test exposing (Test, describe, test)
import TestHelpers exposing (courtroomName, teamA, teamB)
import Trial


unsafePairing : Pairing.Pairing
unsafePairing =
    case Pairing.create teamA teamB of
        Ok p ->
            p

        Err _ ->
            Debug.todo "TestHelpers teamA and teamB must differ"


courtroom : Courtroom.Courtroom
courtroom =
    Courtroom.create (courtroomName "Dept 1")


suite : Test
suite =
    describe "Trial"
        [ describe "fromPairing"
            [ test "nothing assigned returns Nothing" <|
                \_ ->
                    unsafePairing
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "only courtroom assigned returns Nothing" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "only judge assigned returns Nothing" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Expect.equal Nothing
            , test "both assigned returns Just Trial" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> expectJust
            , test "trial has correct prosecution" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Maybe.map Trial.prosecution
                        |> Expect.equal (Just teamA)
            , test "trial has correct defense" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Maybe.map Trial.defense
                        |> Expect.equal (Just teamB)
            , test "trial has correct courtroom" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Maybe.map Trial.courtroom
                        |> Expect.equal (Just courtroom)
            , test "trial has correct judge" <|
                \_ ->
                    unsafePairing
                        |> Pairing.assignCourtroom courtroom
                        |> Pairing.assignJudge Judge
                        |> Trial.fromPairing
                        |> Maybe.map Trial.judge
                        |> Expect.equal (Just Judge)
            ]
        ]


expectJust : Maybe a -> Expect.Expectation
expectJust maybe =
    case maybe of
        Just _ ->
            Expect.pass

        Nothing ->
            Expect.fail "Expected Just, got Nothing"
