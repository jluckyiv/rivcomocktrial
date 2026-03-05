module ActiveTrialTest exposing (suite)

import ActiveTrial exposing (TrialStatus(..))
import Assignment exposing (Assignment(..))
import Courtroom
import Error exposing (Error(..))
import Expect
import Pairing
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( courtroomName
        , teamA
        , teamB
        , testJudge
        )
import Trial


testTrial : Trial.Trial
testTrial =
    let
        pairing =
            case Pairing.create teamA teamB of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "testTrial pairing must be valid"

        courtroom =
            Courtroom.create (courtroomName "Dept 1")
    in
    case
        pairing
            |> Pairing.assignCourtroom courtroom
            |> Pairing.assignJudge testJudge
            |> Trial.fromPairing
    of
        Just t ->
            t

        Nothing ->
            Debug.todo "testTrial must be valid"


suite : Test
suite =
    describe "ActiveTrial"
        [ describe "fromTrial"
            [ test "creates with AwaitingCheckIn status" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.status
                        |> Expect.equal AwaitingCheckIn
            , test "preserves trial data" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.trial
                        |> Expect.equal testTrial
            ]
        , describe "startTrial"
            [ test "AwaitingCheckIn -> InProgress succeeds" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.map ActiveTrial.status
                        |> Expect.equal (Ok InProgress)
            , test "InProgress -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.startTrial
                        |> Expect.err
            , test "Complete -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.startTrial
                        |> Expect.err
            , test "Verified -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Result.andThen ActiveTrial.startTrial
                        |> Expect.err
            ]
        , describe "completeTrial"
            [ test "InProgress -> Complete succeeds" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.map ActiveTrial.status
                        |> Expect.equal (Ok Complete)
            , test "AwaitingCheckIn -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.completeTrial
                        |> Expect.err
            , test "Complete -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Expect.err
            , test "Verified -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Expect.err
            ]
        , describe "verifyTrial"
            [ test "Complete -> Verified succeeds" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Result.map ActiveTrial.status
                        |> Expect.equal (Ok Verified)
            , test "AwaitingCheckIn -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.verifyTrial
                        |> Expect.err
            , test "InProgress -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Expect.err
            , test "Verified -> fails" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Expect.err
            ]
        , describe "full lifecycle"
            [ test "AwaitingCheckIn -> InProgress -> Complete -> Verified" <|
                \_ ->
                    ActiveTrial.fromTrial testTrial
                        |> ActiveTrial.startTrial
                        |> Result.andThen ActiveTrial.completeTrial
                        |> Result.andThen ActiveTrial.verifyTrial
                        |> Result.map ActiveTrial.status
                        |> Expect.equal (Ok Verified)
            ]
        , describe "statusToString"
            [ test "AwaitingCheckIn" <|
                \_ ->
                    ActiveTrial.statusToString AwaitingCheckIn
                        |> Expect.equal "Awaiting Check-In"
            , test "InProgress" <|
                \_ ->
                    ActiveTrial.statusToString InProgress
                        |> Expect.equal "In Progress"
            , test "Complete" <|
                \_ ->
                    ActiveTrial.statusToString Complete
                        |> Expect.equal "Complete"
            , test "Verified" <|
                \_ ->
                    ActiveTrial.statusToString Verified
                        |> Expect.equal "Verified"
            ]
        ]
