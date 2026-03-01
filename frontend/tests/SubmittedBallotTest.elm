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
        [ createSuite
        , pointsSuite
        , weightSuite
        , accessorSuite
        , weightedPointsSuite
        ]


createSuite : Test
createSuite =
    let
        p =
            unsafePoints 7
    in
    describe "create"
        [ test "succeeds with non-empty presentations" <|
            \_ ->
                SubmittedBallot.create
                    [ Opening Prosecution alice p ]
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty presentations" <|
            \_ ->
                SubmittedBallot.create []
                    |> isErr
                    |> Expect.equal True
        , test "presentations round-trip" <|
            \_ ->
                let
                    list =
                        [ Opening Prosecution alice p
                        , Closing Defense alice p
                        ]
                in
                SubmittedBallot.create list
                    |> Result.map SubmittedBallot.presentations
                    |> Expect.equal (Ok list)
        ]


pointsSuite : Test
pointsSuite =
    describe "Points"
        [ test "fromInt 1 succeeds" <|
            \_ ->
                SubmittedBallot.fromInt 1
                    |> isOk
                    |> Expect.equal True
        , test "fromInt 10 succeeds" <|
            \_ ->
                SubmittedBallot.fromInt 10
                    |> isOk
                    |> Expect.equal True
        , test "fromInt 5 round-trips via toInt" <|
            \_ ->
                SubmittedBallot.fromInt 5
                    |> Result.map SubmittedBallot.toInt
                    |> Expect.equal (Ok 5)
        , test "fromInt 0 fails" <|
            \_ ->
                SubmittedBallot.fromInt 0
                    |> isErr
                    |> Expect.equal True
        , test "fromInt 11 fails" <|
            \_ ->
                SubmittedBallot.fromInt 11
                    |> isErr
                    |> Expect.equal True
        , test "fromInt -1 fails" <|
            \_ ->
                SubmittedBallot.fromInt -1
                    |> isErr
                    |> Expect.equal True
        ]


weightSuite : Test
weightSuite =
    let
        pts =
            unsafePoints 5
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
            unsafePoints 7
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
            unsafePoints 8
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


{-| Unsafe helper for tests only — avoids Result
unwrapping noise.
-}
unsafePoints : Int -> Points
unsafePoints n =
    case SubmittedBallot.fromInt n of
        Ok p ->
            p

        Err _ ->
            Debug.todo ("Invalid points: " ++ String.fromInt n)


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
