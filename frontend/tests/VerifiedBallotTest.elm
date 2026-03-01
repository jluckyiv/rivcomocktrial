module VerifiedBallotTest exposing (suite)

import Expect
import Side exposing (Side(..))
import Student exposing (Student)
import SubmittedBallot
    exposing
        ( ScoredPresentation(..)
        )
import Test exposing (Test, describe, test)
import TestHelpers
import VerifiedBallot


alice : Student
alice =
    TestHelpers.alice


pts : Int -> SubmittedBallot.Points
pts n =
    case SubmittedBallot.fromInt n of
        Ok p ->
            p

        Err _ ->
            Debug.todo ("Invalid points: " ++ String.fromInt n)


makeBallot : List ScoredPresentation -> SubmittedBallot.SubmittedBallot
makeBallot list =
    case SubmittedBallot.create list of
        Ok b ->
            b

        Err _ ->
            Debug.todo "Ballot must have presentations"


suite : Test
suite =
    let
        opening =
            Opening Prosecution alice (pts 7)

        closing =
            Closing Defense alice (pts 9)

        ballot =
            makeBallot [ opening, closing ]
    in
    describe "VerifiedBallot"
        [ describe "verify"
            [ test "preserves original's presentations" <|
                \_ ->
                    ballot
                        |> VerifiedBallot.verify
                        |> VerifiedBallot.presentations
                        |> Expect.equal [ opening, closing ]
            , test "links back to original" <|
                \_ ->
                    ballot
                        |> VerifiedBallot.verify
                        |> VerifiedBallot.original
                        |> Expect.equal ballot
            ]
        , describe "verifyWithCorrections"
            [ test "uses corrected presentations" <|
                \_ ->
                    let
                        corrected =
                            [ Opening Prosecution alice (pts 8)
                            , closing
                            ]
                    in
                    VerifiedBallot.verifyWithCorrections ballot corrected
                        |> VerifiedBallot.presentations
                        |> Expect.equal corrected
            , test "still links to original" <|
                \_ ->
                    let
                        corrected =
                            [ Opening Prosecution alice (pts 8) ]
                    in
                    VerifiedBallot.verifyWithCorrections ballot corrected
                        |> VerifiedBallot.original
                        |> Expect.equal ballot
            ]
        ]
