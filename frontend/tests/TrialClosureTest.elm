module TrialClosureTest exposing (suite)

import ActiveTrial exposing (TrialStatus(..))
import BallotTracking
import Error exposing (Error)
import Expect
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( testScorer
        , testSubmittedBallot
        , testTrial
        , volunteerName
        )
import TrialClosure
import TrialRole exposing (TrialRole(..))
import VerifiedBallot
import Volunteer


scorer2 : Volunteer.Volunteer
scorer2 =
    Volunteer.create
        (volunteerName "Second" "Scorer")
        (TestHelpers.email "scorer2@example.com")
        ScorerRole


suite : Test
suite =
    describe "TrialClosure"
        [ completeTrialTests
        , verifyTrialTests
        , integrationTests
        ]


completeTrialTests : Test
completeTrialTests =
    describe "completeTrial"
        [ test "all submitted + InProgress -> Ok Complete" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Result.map ActiveTrial.status
                    |> Expect.equal (Ok Complete)
        , test "AwaitingSubmissions -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Expect.err
        , test "AwaitingCheckIn status -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Expect.err
        , test "Complete status -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Expect.err
        , test "Verified status -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> Result.andThen ActiveTrial.verifyTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Expect.err
        ]


verifyTrialTests : Test
verifyTrialTests =
    describe "verifyTrial"
        [ test "AllVerified + Complete -> Ok Verified" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> Result.andThen
                                (BallotTracking.verifyBallot
                                    testScorer
                                    verifiedBallot
                                )
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> resultOrFail
                in
                TrialClosure.verifyTrial tracking activeTrial
                    |> Result.map ActiveTrial.status
                    |> Expect.equal (Ok Verified)
        , test "AwaitingVerification + Complete -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> resultOrFail
                in
                TrialClosure.verifyTrial tracking activeTrial
                    |> Expect.err
        , test "AwaitingSubmissions + Complete -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer ]

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> resultOrFail
                in
                TrialClosure.verifyTrial tracking activeTrial
                    |> Expect.err
        , test "AllVerified + InProgress -> Err" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> Result.andThen
                                (BallotTracking.verifyBallot
                                    testScorer
                                    verifiedBallot
                                )
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail
                in
                TrialClosure.verifyTrial tracking activeTrial
                    |> Expect.err
        ]


integrationTests : Test
integrationTests =
    describe "integration"
        [ test "full lifecycle: submit -> complete -> verify -> verify trial" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> Result.andThen
                                (BallotTracking.verifyBallot
                                    testScorer
                                    verifiedBallot
                                )
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Result.andThen
                        (TrialClosure.verifyTrial tracking)
                    |> Result.map ActiveTrial.status
                    |> Expect.equal (Ok Verified)
        , test "correction round-trip: verify -> reopen -> replace -> re-verify" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    correctedBallot =
                        VerifiedBallot.verifyWithCorrections
                            testSubmittedBallot
                            []

                    tracking =
                        BallotTracking.create testTrial [ testScorer ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> Result.andThen
                                (BallotTracking.verifyBallot
                                    testScorer
                                    verifiedBallot
                                )
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail

                    verifiedTrial =
                        TrialClosure.completeTrial tracking activeTrial
                            |> Result.andThen
                                (TrialClosure.verifyTrial tracking)
                            |> resultOrFail

                    reopenedTrial =
                        ActiveTrial.reopenTrial verifiedTrial
                            |> resultOrFail

                    updatedTracking =
                        BallotTracking.replaceVerifiedBallot
                            testScorer
                            correctedBallot
                            tracking
                            |> resultOrFail
                in
                TrialClosure.verifyTrial updatedTracking reopenedTrial
                    |> Result.map ActiveTrial.status
                    |> Expect.equal (Ok Verified)
        , test "complete with partial submissions -> Err" <|
            \_ ->
                let
                    tracking =
                        BallotTracking.create testTrial [ testScorer, scorer2 ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> resultOrFail
                in
                TrialClosure.completeTrial tracking activeTrial
                    |> Expect.err
        , test "verify with partial verifications -> Err" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    tracking =
                        BallotTracking.create testTrial [ testScorer, scorer2 ]
                            |> BallotTracking.submitBallot
                                testScorer
                                testSubmittedBallot
                            |> Result.andThen
                                (BallotTracking.submitBallot
                                    scorer2
                                    testSubmittedBallot
                                )
                            |> Result.andThen
                                (BallotTracking.verifyBallot
                                    testScorer
                                    verifiedBallot
                                )
                            |> resultOrFail

                    activeTrial =
                        ActiveTrial.fromTrial testTrial
                            |> ActiveTrial.startTrial
                            |> Result.andThen ActiveTrial.completeTrial
                            |> resultOrFail
                in
                TrialClosure.verifyTrial tracking activeTrial
                    |> Expect.err
        ]



-- HELPERS


resultOrFail : Result (List Error) a -> a
resultOrFail result =
    case result of
        Ok value ->
            value

        Err errors ->
            Debug.todo
                ("Expected Ok, got Err: "
                    ++ Debug.toString errors
                )
