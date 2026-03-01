module ElimResultTest exposing (suite)

import ElimResult exposing (ElimVerdict(..), ScorecardResult(..))
import Expect
import PresiderBallot
import Side exposing (Side(..))
import Student exposing (Student)
import SubmittedBallot exposing (ScoredPresentation(..))
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
        Ok p ->
            p

        Err _ ->
            Debug.todo ("Invalid points: " ++ String.fromInt n)


ballot : List ScoredPresentation -> VerifiedBallot.VerifiedBallot
ballot list =
    case SubmittedBallot.create list of
        Ok b ->
            VerifiedBallot.verify b

        Err _ ->
            Debug.todo "Ballot must have presentations"


pWins : VerifiedBallot.VerifiedBallot
pWins =
    ballot
        [ Opening Prosecution alice (pts 8)
        , Opening Defense alice (pts 6)
        ]


dWins : VerifiedBallot.VerifiedBallot
dWins =
    ballot
        [ Opening Prosecution alice (pts 5)
        , Opening Defense alice (pts 9)
        ]


tied : VerifiedBallot.VerifiedBallot
tied =
    ballot
        [ Opening Prosecution alice (pts 7)
        , Opening Defense alice (pts 7)
        ]


suite : Test
suite =
    describe "ElimResult"
        [ scorecardResultSuite
        , verdictSuite
        , presiderSuite
        ]


scorecardResultSuite : Test
scorecardResultSuite =
    describe "scorecardResult"
        [ test "P wins when P Court Total higher" <|
            \_ ->
                ElimResult.scorecardResult pWins
                    |> Expect.equal ProsecutionWon
        , test "D wins when D Court Total higher" <|
            \_ ->
                ElimResult.scorecardResult dWins
                    |> Expect.equal DefenseWon
        , test "tied when Court Totals equal" <|
            \_ ->
                ElimResult.scorecardResult tied
                    |> Expect.equal ScorecardTied
        ]


verdictSuite : Test
verdictSuite =
    describe "elimVerdict"
        [ test "majority P → ProsecutionAdvances" <|
            \_ ->
                [ pWins, pWins, dWins ]
                    |> ElimResult.elimVerdict
                    |> Expect.equal ProsecutionAdvances
        , test "majority D → DefenseAdvances" <|
            \_ ->
                [ dWins, dWins, pWins ]
                    |> ElimResult.elimVerdict
                    |> Expect.equal DefenseAdvances
        , test "equal wins → ScorecardsTied" <|
            \_ ->
                [ pWins, dWins ]
                    |> ElimResult.elimVerdict
                    |> Expect.equal ScorecardsTied
        , test "tied scorecards count toward neither" <|
            \_ ->
                [ pWins, dWins, tied ]
                    |> ElimResult.elimVerdict
                    |> Expect.equal ScorecardsTied
        , test "3-2 split → majority advances" <|
            \_ ->
                [ pWins, pWins, pWins, dWins, dWins ]
                    |> ElimResult.elimVerdict
                    |> Expect.equal ProsecutionAdvances
        ]


presiderSuite : Test
presiderSuite =
    describe "elimVerdictWithPresider"
        [ test "returns presider's side when tied" <|
            \_ ->
                ElimResult.elimVerdictWithPresider
                    (PresiderBallot.for Defense)
                    [ pWins, dWins ]
                    |> Expect.equal Defense
        , test "returns majority winner when not tied" <|
            \_ ->
                ElimResult.elimVerdictWithPresider
                    (PresiderBallot.for Defense)
                    [ pWins, pWins, dWins ]
                    |> Expect.equal Prosecution
        ]
