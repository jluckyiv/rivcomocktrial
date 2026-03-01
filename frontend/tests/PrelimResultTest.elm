module PrelimResultTest exposing (suite)

import Expect
import PresiderBallot
import PrelimResult exposing (PrelimVerdict(..))
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


suite : Test
suite =
    describe "PrelimResult"
        [ courtTotalSuite
        , verdictSuite
        , presiderSuite
        ]


courtTotalSuite : Test
courtTotalSuite =
    describe "courtTotal"
        [ test "sums weighted points for Prosecution" <|
            \_ ->
                ballot
                    [ Opening Prosecution alice (pts 7)
                    , Opening Defense alice (pts 9)
                    ]
                    |> PrelimResult.courtTotal Prosecution
                    |> Expect.equal 7
        , test "sums weighted points for Defense" <|
            \_ ->
                ballot
                    [ Opening Prosecution alice (pts 7)
                    , Opening Defense alice (pts 9)
                    ]
                    |> PrelimResult.courtTotal Defense
                    |> Expect.equal 9
        , test "Clerk counts toward Prosecution" <|
            \_ ->
                ballot
                    [ ClerkPerformance alice (pts 8) ]
                    |> PrelimResult.courtTotal Prosecution
                    |> Expect.equal 8
        , test "Bailiff counts toward Defense" <|
            \_ ->
                ballot
                    [ BailiffPerformance alice (pts 6) ]
                    |> PrelimResult.courtTotal Defense
                    |> Expect.equal 6
        , test "Pretrial is double-weighted" <|
            \_ ->
                ballot
                    [ Pretrial Prosecution alice (pts 8) ]
                    |> PrelimResult.courtTotal Prosecution
                    |> Expect.equal 16
        , test "Closing is double-weighted" <|
            \_ ->
                ballot
                    [ Closing Defense alice (pts 7) ]
                    |> PrelimResult.courtTotal Defense
                    |> Expect.equal 14
        , test "sums multiple presentations for one side" <|
            \_ ->
                ballot
                    [ Opening Prosecution alice (pts 7)
                    , DirectExamination Prosecution alice (pts 8)
                    , Pretrial Prosecution alice (pts 6)
                    ]
                    |> PrelimResult.courtTotal Prosecution
                    |> Expect.equal (7 + 8 + 12)
        ]


verdictSuite : Test
verdictSuite =
    describe "prelimVerdict"
        [ test "higher Prosecution Court Total → ProsecutionWins" <|
            \_ ->
                [ ballot
                    [ Opening Prosecution alice (pts 8)
                    , Opening Defense alice (pts 6)
                    ]
                ]
                    |> PrelimResult.prelimVerdict
                    |> Expect.equal ProsecutionWins
        , test "higher Defense Court Total → DefenseWins" <|
            \_ ->
                [ ballot
                    [ Opening Prosecution alice (pts 5)
                    , Opening Defense alice (pts 9)
                    ]
                ]
                    |> PrelimResult.prelimVerdict
                    |> Expect.equal DefenseWins
        , test "equal Court Totals → CourtTotalTied" <|
            \_ ->
                [ ballot
                    [ Opening Prosecution alice (pts 7)
                    , Opening Defense alice (pts 7)
                    ]
                ]
                    |> PrelimResult.prelimVerdict
                    |> Expect.equal CourtTotalTied
        , test "sums across multiple ballots" <|
            \_ ->
                [ ballot
                    [ Opening Prosecution alice (pts 8)
                    , Opening Defense alice (pts 6)
                    ]
                , ballot
                    [ Opening Prosecution alice (pts 5)
                    , Opening Defense alice (pts 9)
                    ]
                ]
                    |> PrelimResult.prelimVerdict
                    |> Expect.equal DefenseWins
        ]


presiderSuite : Test
presiderSuite =
    describe "prelimVerdictWithPresider"
        [ test "returns presider's side when tied" <|
            \_ ->
                let
                    ballots =
                        [ ballot
                            [ Opening Prosecution alice (pts 7)
                            , Opening Defense alice (pts 7)
                            ]
                        ]

                    presider =
                        PresiderBallot.for Defense
                in
                PrelimResult.prelimVerdictWithPresider presider ballots
                    |> Expect.equal Defense
        , test "returns Court Total winner when not tied" <|
            \_ ->
                let
                    ballots =
                        [ ballot
                            [ Opening Prosecution alice (pts 9)
                            , Opening Defense alice (pts 5)
                            ]
                        ]

                    presider =
                        PresiderBallot.for Defense
                in
                PrelimResult.prelimVerdictWithPresider presider ballots
                    |> Expect.equal Prosecution
        ]
