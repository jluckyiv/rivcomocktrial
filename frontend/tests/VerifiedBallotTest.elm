module VerifiedBallotTest exposing (suite)

import Expect
import Side exposing (Side(..))
import Student exposing (Student)
import SubmittedBallot
    exposing
        ( ScoredPresentation(..)
        )
import Test exposing (Test, describe, test)
import VerifiedBallot


alice : Student
alice =
    { name =
        { first = "Alice"
        , last = "Smith"
        , preferred = Nothing
        }
    , pronouns = Student.SheHer
    }


pts : Int -> SubmittedBallot.Points
pts n =
    case SubmittedBallot.fromInt n of
        Just p ->
            p

        Nothing ->
            pts 5


suite : Test
suite =
    let
        opening =
            Opening Prosecution alice (pts 7)

        closing =
            Closing Defense alice (pts 9)

        ballot =
            { presentations = [ opening, closing ] }
    in
    describe "VerifiedBallot"
        [ describe "verify"
            [ test "preserves original's presentations" <|
                \_ ->
                    ballot
                        |> VerifiedBallot.verify
                        |> .presentations
                        |> Expect.equal [ opening, closing ]
            , test "links back to original" <|
                \_ ->
                    ballot
                        |> VerifiedBallot.verify
                        |> .original
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
                        |> .presentations
                        |> Expect.equal corrected
            , test "still links to original" <|
                \_ ->
                    let
                        corrected =
                            [ Opening Prosecution alice (pts 8) ]
                    in
                    VerifiedBallot.verifyWithCorrections ballot corrected
                        |> .original
                        |> Expect.equal ballot
            ]
        ]
