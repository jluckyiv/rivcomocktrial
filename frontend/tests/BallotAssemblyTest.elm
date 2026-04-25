module BallotAssemblyTest exposing (suite)

import Api
    exposing
        ( BallotCorrection
        , BallotScore
        , PresiderBallotRecord
        , PresentationType(..)
        , RosterSide
        )
import BallotAssembly
import Expect
import PresiderBallot
import Side exposing (Side)
import SubmittedBallot exposing (Weight(..))
import Test exposing (Test, describe, test)
import VerifiedBallot


suite : Test
suite =
    describe "BallotAssembly"
        [ assembleStudentSuite
        , assembleScoredPresentationSuite
        , assembleSubmittedBallotSuite
        , assembleVerifiedBallotSuite
        , assemblePresiderBallotSuite
        ]


assembleStudentSuite : Test
assembleStudentSuite =
    describe "assembleStudent (via assembleScoredPresentation)"
        [ test "parses first and last name" <|
            \_ ->
                fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> isOk
                    |> Expect.equal True
        , test "handles compound first name" <|
            \_ ->
                fakeBallotScore PretrialPresentation Api.Prosecution "Mary Jane Smith" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> isOk
                    |> Expect.equal True
        , test "handles single-word name (no space)" <|
            \_ ->
                fakeBallotScore PretrialPresentation Api.Prosecution "Madonna" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> isOk
                    |> Expect.equal True
        ]


assembleScoredPresentationSuite : Test
assembleScoredPresentationSuite =
    describe "assembleScoredPresentation"
        [ test "pretrial maps to Pretrial constructor (double weight)" <|
            \_ ->
                fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Double)
        , test "opening maps to Opening constructor (single weight)" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 8
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Single)
        , test "closing maps to Closing constructor (double weight)" <|
            \_ ->
                fakeBallotScore ClosingPresentation Api.Defense "Bob Jones" 9
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Double)
        , test "direct_examination is single weight" <|
            \_ ->
                fakeBallotScore DirectExaminationPresentation Api.Prosecution "Alice Smith" 6
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Single)
        , test "cross_examination is single weight" <|
            \_ ->
                fakeBallotScore CrossExaminationPresentation Api.Defense "Bob Jones" 5
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Single)
        , test "witness_examination is single weight" <|
            \_ ->
                fakeBallotScore WitnessExaminationPresentation Api.Prosecution "Alice Smith" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.weight
                    |> Expect.equal (Ok Single)
        , test "clerk_performance ignores api side (domain type hard-codes Prosecution)" <|
            \_ ->
                fakeBallotScore ClerkPerformancePresentation Api.Defense "Alice Smith" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.side
                    |> Expect.equal (Ok Side.Prosecution)
        , test "bailiff_performance ignores api side (domain type hard-codes Defense)" <|
            \_ ->
                fakeBallotScore BailiffPerformancePresentation Api.Prosecution "Bob Jones" 7
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.side
                    |> Expect.equal (Ok Side.Defense)
        , test "side is preserved for scored presentations" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Defense "Bob Jones" 8
                    |> BallotAssembly.assembleScoredPresentation
                    |> Result.map SubmittedBallot.side
                    |> Expect.equal (Ok Side.Defense)
        , test "points above range (11) returns error" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 11
                    |> BallotAssembly.assembleScoredPresentation
                    |> isErr
                    |> Expect.equal True
        , test "points below range (0) returns error" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 0
                    |> BallotAssembly.assembleScoredPresentation
                    |> isErr
                    |> Expect.equal True
        , test "points at minimum (1) succeeds" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 1
                    |> BallotAssembly.assembleScoredPresentation
                    |> isOk
                    |> Expect.equal True
        , test "points at maximum (10) succeeds" <|
            \_ ->
                fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 10
                    |> BallotAssembly.assembleScoredPresentation
                    |> isOk
                    |> Expect.equal True
        ]


assembleSubmittedBallotSuite : Test
assembleSubmittedBallotSuite =
    describe "assembleSubmittedBallot"
        [ test "empty list fails" <|
            \_ ->
                BallotAssembly.assembleSubmittedBallot []
                    |> isErr
                    |> Expect.equal True
        , test "valid list succeeds" <|
            \_ ->
                BallotAssembly.assembleSubmittedBallot simpleBallotScores
                    |> isOk
                    |> Expect.equal True
        , test "scores sorted by sort_order" <|
            \_ ->
                let
                    closing =
                        fakeBallotScore ClosingPresentation Api.Defense "Bob Jones" 9

                    pretrial =
                        fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7

                    outOfOrder =
                        [ { closing | sortOrder = 2 }
                        , { pretrial | sortOrder = 1 }
                        ]
                in
                BallotAssembly.assembleSubmittedBallot outOfOrder
                    |> Result.map SubmittedBallot.presentations
                    |> Result.map (List.map SubmittedBallot.weight)
                    |> Expect.equal (Ok [ Double, Double ])
        , test "invalid points in any score fails the whole ballot" <|
            \_ ->
                let
                    base =
                        fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 11

                    badScore =
                        { base | sortOrder = 2 }
                in
                BallotAssembly.assembleSubmittedBallot
                    [ fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7
                    , badScore
                    ]
                    |> isErr
                    |> Expect.equal True
        ]


assembleVerifiedBallotSuite : Test
assembleVerifiedBallotSuite =
    describe "assembleVerifiedBallot"
        [ test "no corrections: presentations match original" <|
            \_ ->
                case BallotAssembly.assembleSubmittedBallot simpleBallotScores of
                    Err _ ->
                        Expect.fail "Could not assemble test ballot"

                    Ok original ->
                        case BallotAssembly.assembleVerifiedBallot original simpleBallotScores [] of
                            Err _ ->
                                Expect.fail "Could not assemble verified ballot"

                            Ok verified ->
                                VerifiedBallot.presentations verified
                                    |> Expect.equal (SubmittedBallot.presentations original)
        , test "with correction: corrected points replace original" <|
            \_ ->
                case BallotAssembly.assembleSubmittedBallot simpleBallotScores of
                    Err _ ->
                        Expect.fail "Could not assemble test ballot"

                    Ok original ->
                        let
                            firstScore =
                                List.head simpleBallotScores
                                    |> Maybe.withDefault
                                        (fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7)

                            correction : BallotCorrection
                            correction =
                                { id = "corr1"
                                , ballot = "ballot1"
                                , originalScoreId = firstScore.id
                                , correctedPoints = 3
                                , reason = Just "Entry error"
                                , correctedAt = "2026-01-01"
                                , created = "2026-01-01"
                                , updated = "2026-01-01"
                                }
                        in
                        case BallotAssembly.assembleVerifiedBallot original simpleBallotScores [ correction ] of
                            Err _ ->
                                Expect.fail "Could not assemble verified ballot"

                            Ok verified ->
                                VerifiedBallot.presentations verified
                                    |> List.head
                                    |> Maybe.map SubmittedBallot.points
                                    |> Maybe.map SubmittedBallot.toInt
                                    |> Expect.equal (Just 3)
        , test "original is preserved under corrections" <|
            \_ ->
                case BallotAssembly.assembleSubmittedBallot simpleBallotScores of
                    Err _ ->
                        Expect.fail "Could not assemble test ballot"

                    Ok original ->
                        let
                            firstScore =
                                List.head simpleBallotScores
                                    |> Maybe.withDefault
                                        (fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7)

                            correction : BallotCorrection
                            correction =
                                { id = "corr1"
                                , ballot = "ballot1"
                                , originalScoreId = firstScore.id
                                , correctedPoints = 3
                                , reason = Nothing
                                , correctedAt = "2026-01-01"
                                , created = "2026-01-01"
                                , updated = "2026-01-01"
                                }
                        in
                        case BallotAssembly.assembleVerifiedBallot original simpleBallotScores [ correction ] of
                            Err _ ->
                                Expect.fail "Could not assemble verified ballot"

                            Ok verified ->
                                VerifiedBallot.original verified
                                    |> SubmittedBallot.presentations
                                    |> Expect.equal (SubmittedBallot.presentations original)
        ]


assemblePresiderBallotSuite : Test
assemblePresiderBallotSuite =
    describe "assemblePresiderBallot"
        [ test "Prosecution winner_side maps to Prosecution" <|
            \_ ->
                fakePresiderBallotRecord Api.Prosecution
                    |> BallotAssembly.assemblePresiderBallot
                    |> PresiderBallot.winner
                    |> Expect.equal Side.Prosecution
        , test "Defense winner_side maps to Defense" <|
            \_ ->
                fakePresiderBallotRecord Api.Defense
                    |> BallotAssembly.assemblePresiderBallot
                    |> PresiderBallot.winner
                    |> Expect.equal Side.Defense
        ]



-- HELPERS


fakeBallotScore : PresentationType -> RosterSide -> String -> Int -> BallotScore
fakeBallotScore presentationType side name pts =
    { id = "score-1"
    , ballot = "ballot1"
    , presentation = presentationType
    , side = side
    , studentName = name
    , rosterEntry = Nothing
    , points = pts
    , sortOrder = 0
    , created = "2026-01-01"
    , updated = "2026-01-01"
    }


simpleBallotScores : List BallotScore
simpleBallotScores =
    let
        s1 =
            fakeBallotScore PretrialPresentation Api.Prosecution "Alice Smith" 7

        s2 =
            fakeBallotScore OpeningPresentation Api.Prosecution "Alice Smith" 8

        s3 =
            fakeBallotScore ClosingPresentation Api.Defense "Bob Jones" 9
    in
    [ { s1 | id = "score-1", sortOrder = 1 }
    , { s2 | id = "score-2", sortOrder = 2 }
    , { s3 | id = "score-3", sortOrder = 3 }
    ]


fakePresiderBallotRecord : RosterSide -> PresiderBallotRecord
fakePresiderBallotRecord side =
    { id = "presider1"
    , scorerToken = "token1"
    , trial = "trial1"
    , winnerSide = side
    , submittedAt = "2026-01-01"
    , created = "2026-01-01"
    , updated = "2026-01-01"
    }


isOk : Result e a -> Bool
isOk result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


isErr : Result e a -> Bool
isErr result =
    not (isOk result)
