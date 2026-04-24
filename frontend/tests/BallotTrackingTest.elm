module BallotTrackingTest exposing (suite)

import BallotTracking
    exposing
        ( PresiderStatus(..)
        , ScorerStatus(..)
        )
import Expect
import PresiderBallot
import Side exposing (Side(..))
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( testScorer
        , testSubmittedBallot
        , testTrial
        , volunteerName
        )
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
    describe "BallotTracking"
        [ createTests
        , submitTests
        , verifyTests
        , replaceTests
        , presiderTests
        , scorerStatusTests
        , presiderStatusTests
        , lifecycleTests
        ]


createTests : Test
createTests =
    describe "create"
        [ test "preserves trial" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.trial
                    |> Expect.equal testTrial
        , test "preserves expected scorers" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer, scorer2 ]
                    |> BallotTracking.expectedScorers
                    |> List.length
                    |> Expect.equal 2
        , test "starts with empty submitted" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitted
                    |> List.length
                    |> Expect.equal 0
        , test "starts with empty verified" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.verified
                    |> List.length
                    |> Expect.equal 0
        , test "starts with no presider ballot" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.presiderBallot
                    |> Expect.equal Nothing
        ]


submitTests : Test
submitTests =
    describe "submitBallot"
        [ test "valid submission succeeds" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Expect.ok
        , test "valid submission adds to submitted list" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.map BallotTracking.submitted
                    |> Result.map List.length
                    |> Expect.equal (Ok 1)
        , test "unknown volunteer fails" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        scorer2
                        testSubmittedBallot
                    |> Expect.err
        , test "duplicate submission fails" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.submitBallot
                            testScorer
                            testSubmittedBallot
                        )
                    |> Expect.err
        ]


verifyTests : Test
verifyTests =
    describe "verifyBallot"
        [ test "valid verification succeeds" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Expect.ok
        , test "volunteer with no submission fails" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.verifyBallot
                        testScorer
                        verifiedBallot
                    |> Expect.err
        , test "duplicate verification fails" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Expect.err
        ]


presiderTests : Test
presiderTests =
    describe "submitPresiderBallot"
        [ test "succeeds when none exists" <|
            \_ ->
                let
                    ballot =
                        PresiderBallot.for Prosecution
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitPresiderBallot ballot
                    |> Expect.ok
        , test "fails when already submitted" <|
            \_ ->
                let
                    ballot =
                        PresiderBallot.for Prosecution
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitPresiderBallot ballot
                    |> Result.andThen
                        (BallotTracking.submitPresiderBallot ballot)
                    |> Expect.err
        ]


scorerStatusTests : Test
scorerStatusTests =
    describe "scorerStatus"
        [ test "initially AwaitingSubmissions with all scorers" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer, scorer2 ]
                    |> BallotTracking.scorerStatus
                    |> expectAwaitingSubmissions 2
        , test "after one submission, AwaitingSubmissions with remaining" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer, scorer2 ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.map BallotTracking.scorerStatus
                    |> Result.map (expectAwaitingSubmissions 1)
                    |> expectOkPass
        , test "after all submissions, AwaitingVerification" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.map BallotTracking.scorerStatus
                    |> Expect.equal (Ok AwaitingVerification)
        , test "after all verifications, AllVerified" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Result.map BallotTracking.scorerStatus
                    |> Expect.equal (Ok AllVerified)
        ]


presiderStatusTests : Test
presiderStatusTests =
    describe "presiderStatus"
        [ test "initially AwaitingPresiderBallot" <|
            \_ ->
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.presiderStatus
                    |> Expect.equal AwaitingPresiderBallot
        , test "after submit, PresiderBallotReceived" <|
            \_ ->
                let
                    ballot =
                        PresiderBallot.for Prosecution
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitPresiderBallot ballot
                    |> Result.map BallotTracking.presiderStatus
                    |> Expect.equal (Ok PresiderBallotReceived)
        ]


replaceTests : Test
replaceTests =
    describe "replaceVerifiedBallot"
        [ test "replaces existing verified ballot" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    correctedBallot =
                        VerifiedBallot.verifyWithCorrections
                            testSubmittedBallot
                            []
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Result.andThen
                        (BallotTracking.replaceVerifiedBallot
                            testScorer
                            correctedBallot
                        )
                    |> Result.map BallotTracking.verified
                    |> Result.map List.length
                    |> Expect.equal (Ok 1)
        , test "fails when volunteer has no verified ballot" <|
            \_ ->
                let
                    correctedBallot =
                        VerifiedBallot.verifyWithCorrections
                            testSubmittedBallot
                            []
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.replaceVerifiedBallot
                            testScorer
                            correctedBallot
                        )
                    |> Expect.err
        , test "preserves other verified ballots" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot

                    correctedBallot =
                        VerifiedBallot.verifyWithCorrections
                            testSubmittedBallot
                            []
                in
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
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            scorer2
                            verifiedBallot
                        )
                    |> Result.andThen
                        (BallotTracking.replaceVerifiedBallot
                            testScorer
                            correctedBallot
                        )
                    |> Result.map BallotTracking.verified
                    |> Result.map List.length
                    |> Expect.equal (Ok 2)
        ]


lifecycleTests : Test
lifecycleTests =
    describe "full lifecycle"
        [ test "create -> submit all -> verify all -> AllVerified" <|
            \_ ->
                let
                    verifiedBallot =
                        VerifiedBallot.verify testSubmittedBallot
                in
                BallotTracking.create testTrial [ testScorer ]
                    |> BallotTracking.submitBallot
                        testScorer
                        testSubmittedBallot
                    |> Result.andThen
                        (BallotTracking.verifyBallot
                            testScorer
                            verifiedBallot
                        )
                    |> Result.map BallotTracking.scorerStatus
                    |> Expect.equal (Ok AllVerified)
        ]



-- HELPERS


expectAwaitingSubmissions : Int -> ScorerStatus -> Expect.Expectation
expectAwaitingSubmissions expectedCount scorerStatus_ =
    case scorerStatus_ of
        AwaitingSubmissions missing ->
            List.length missing
                |> Expect.equal expectedCount

        other ->
            Expect.fail
                ("Expected AwaitingSubmissions, got "
                    ++ Debug.toString other
                )


expectOkPass : Result x Expect.Expectation -> Expect.Expectation
expectOkPass result =
    case result of
        Ok expectation ->
            expectation

        Err _ ->
            Expect.fail "Expected Ok, got Err"
