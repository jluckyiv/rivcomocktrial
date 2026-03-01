module SubmittedBallotTest exposing (suite)

import Expect
import Side exposing (Side(..))
import Student exposing (Student)
import SubmittedBallot
    exposing
        ( Points
        , ScoredPresentation(..)
        , Weight(..)
        )
import Test exposing (Test, describe, test)


alice : Student
alice =
    { name =
        { first = "Alice"
        , last = "Smith"
        , preferred = Nothing
        }
    , pronouns = Student.SheHer
    }


suite : Test
suite =
    describe "SubmittedBallot"
        [ pointsSuite
        , weightSuite
        , accessorSuite
        , weightedPointsSuite
        ]


pointsSuite : Test
pointsSuite =
    describe "Points"
        [ test "fromInt 1 succeeds" <|
            \_ ->
                SubmittedBallot.fromInt 1
                    |> Expect.notEqual Nothing
        , test "fromInt 10 succeeds" <|
            \_ ->
                SubmittedBallot.fromInt 10
                    |> Expect.notEqual Nothing
        , test "fromInt 5 round-trips via toInt" <|
            \_ ->
                SubmittedBallot.fromInt 5
                    |> Maybe.map SubmittedBallot.toInt
                    |> Expect.equal (Just 5)
        , test "fromInt 0 fails" <|
            \_ ->
                SubmittedBallot.fromInt 0
                    |> Expect.equal Nothing
        , test "fromInt 11 fails" <|
            \_ ->
                SubmittedBallot.fromInt 11
                    |> Expect.equal Nothing
        , test "fromInt -1 fails" <|
            \_ ->
                SubmittedBallot.fromInt -1
                    |> Expect.equal Nothing
        ]


weightSuite : Test
weightSuite =
    let
        pts =
            Maybe.withDefault (unsafe 5) (SubmittedBallot.fromInt 5)
    in
    describe "weight"
        [ test "Pretrial is Double" <|
            \_ ->
                Pretrial Prosecution alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Double
        , test "Closing is Double" <|
            \_ ->
                Closing Prosecution alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Double
        , test "Opening is Single" <|
            \_ ->
                Opening Prosecution alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        , test "DirectExamination is Single" <|
            \_ ->
                DirectExamination Prosecution alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        , test "CrossExamination is Single" <|
            \_ ->
                CrossExamination Defense alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        , test "WitnessExamination is Single" <|
            \_ ->
                WitnessExamination Defense alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        , test "ClerkPerformance is Single" <|
            \_ ->
                ClerkPerformance alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        , test "BailiffPerformance is Single" <|
            \_ ->
                BailiffPerformance alice pts
                    |> SubmittedBallot.weight
                    |> Expect.equal Single
        ]


accessorSuite : Test
accessorSuite =
    let
        pts =
            Maybe.withDefault (unsafe 5) (SubmittedBallot.fromInt 7)
    in
    describe "accessors"
        [ describe "points"
            [ test "extracts points from Opening" <|
                \_ ->
                    Opening Prosecution alice pts
                        |> SubmittedBallot.points
                        |> SubmittedBallot.toInt
                        |> Expect.equal 7
            , test "extracts points from ClerkPerformance" <|
                \_ ->
                    ClerkPerformance alice pts
                        |> SubmittedBallot.points
                        |> SubmittedBallot.toInt
                        |> Expect.equal 7
            , test "extracts points from BailiffPerformance" <|
                \_ ->
                    BailiffPerformance alice pts
                        |> SubmittedBallot.points
                        |> SubmittedBallot.toInt
                        |> Expect.equal 7
            ]
        , describe "student"
            [ test "extracts student from Opening" <|
                \_ ->
                    Opening Prosecution alice pts
                        |> SubmittedBallot.student
                        |> Expect.equal alice
            , test "extracts student from ClerkPerformance" <|
                \_ ->
                    ClerkPerformance alice pts
                        |> SubmittedBallot.student
                        |> Expect.equal alice
            ]
        , describe "side"
            [ test "Prosecution from Opening" <|
                \_ ->
                    Opening Prosecution alice pts
                        |> SubmittedBallot.side
                        |> Expect.equal Prosecution
            , test "Defense from WitnessExamination" <|
                \_ ->
                    WitnessExamination Defense alice pts
                        |> SubmittedBallot.side
                        |> Expect.equal Defense
            , test "Clerk counts as Prosecution" <|
                \_ ->
                    ClerkPerformance alice pts
                        |> SubmittedBallot.side
                        |> Expect.equal Prosecution
            , test "Bailiff counts as Defense" <|
                \_ ->
                    BailiffPerformance alice pts
                        |> SubmittedBallot.side
                        |> Expect.equal Defense
            ]
        ]


weightedPointsSuite : Test
weightedPointsSuite =
    let
        pts =
            Maybe.withDefault (unsafe 5) (SubmittedBallot.fromInt 8)
    in
    describe "weightedPoints"
        [ test "Single-weighted returns points value" <|
            \_ ->
                Opening Prosecution alice pts
                    |> SubmittedBallot.weightedPoints
                    |> Expect.equal 8
        , test "Double-weighted returns 2x points" <|
            \_ ->
                Pretrial Prosecution alice pts
                    |> SubmittedBallot.weightedPoints
                    |> Expect.equal 16
        ]


{-| Unsafe helper for tests only — avoids Maybe unwrapping noise.
-}
unsafe : Int -> Points
unsafe n =
    case SubmittedBallot.fromInt n of
        Just p ->
            p

        Nothing ->
            unsafe 5
