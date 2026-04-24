module TrialResultTest exposing (suite)

import Error exposing (Error)
import Expect
import PresiderBallot
import Side exposing (Side(..))
import Standings
import SubmittedBallot
import Team exposing (Team)
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( alice
        , bob
        , teamA
        , teamB
        , teamC
        , testTrial
        , trialFor
        )
import TrialResult
import VerifiedBallot


suite : Test
suite =
    describe "TrialResult"
        [ trialResultTests
        , aggregateTests
        , headToHeadTests
        ]



-- Helpers to build ballots with known point totals


pts : Int -> SubmittedBallot.Points
pts n =
    case SubmittedBallot.fromInt n of
        Ok p ->
            p

        Err _ ->
            Debug.todo ("Invalid points: " ++ String.fromInt n)


{-| A ballot where Prosecution gets `pPts` and Defense gets `dPts`.
Uses Opening presentations (weight=Single) so points = raw value.
-}
ballotWith : Int -> Int -> VerifiedBallot.VerifiedBallot
ballotWith pPts dPts =
    let
        submitted =
            case
                SubmittedBallot.create
                    [ SubmittedBallot.Opening Prosecution alice (pts pPts)
                    , SubmittedBallot.Opening Defense bob (pts dPts)
                    ]
            of
                Ok b ->
                    b

                Err _ ->
                    Debug.todo "ballotWith must be valid"
    in
    VerifiedBallot.verify submitted


trialResultTests : Test
trialResultTests =
    describe "trialResult"
        [ test "prosecution wins when P points > D points" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 8 5 ]
                    Nothing
                    |> Result.map TrialResult.winner
                    |> Expect.equal (Ok Prosecution)
        , test "defense wins when D points > P points" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 3 7 ]
                    Nothing
                    |> Result.map TrialResult.winner
                    |> Expect.equal (Ok Defense)
        , test "tied with presider Prosecution → Ok Prosecution" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 5 5 ]
                    (Just (PresiderBallot.for Prosecution))
                    |> Result.map TrialResult.winner
                    |> Expect.equal (Ok Prosecution)
        , test "tied with presider Defense → Ok Defense" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 5 5 ]
                    (Just (PresiderBallot.for Defense))
                    |> Result.map TrialResult.winner
                    |> Expect.equal (Ok Defense)
        , test "tied with no presider → Err" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 5 5 ]
                    Nothing
                    |> Expect.err
        , test "empty ballots → Err" <|
            \_ ->
                TrialResult.trialResult testTrial
                    []
                    Nothing
                    |> Expect.err
        , test "prosecution points match courtTotal sums" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 8 5, ballotWith 7 6 ]
                    Nothing
                    |> Result.map TrialResult.prosecutionPoints
                    |> Expect.equal (Ok 15)
        , test "defense points match courtTotal sums" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 8 5, ballotWith 7 6 ]
                    Nothing
                    |> Result.map TrialResult.defensePoints
                    |> Expect.equal (Ok 11)
        , test "preserves prosecution team" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 8 5 ]
                    Nothing
                    |> Result.map TrialResult.prosecution
                    |> Expect.equal (Ok teamA)
        , test "preserves defense team" <|
            \_ ->
                TrialResult.trialResult testTrial
                    [ ballotWith 8 5 ]
                    Nothing
                    |> Result.map TrialResult.defense
                    |> Expect.equal (Ok teamB)
        ]


aggregateTests : Test
aggregateTests =
    let
        mkResult pTeam dTeam pPts dPts =
            case
                trialResultFor pTeam dTeam pPts dPts
            of
                Ok r ->
                    r

                Err _ ->
                    Debug.todo "aggregate test result must be valid"

        findRecord team entries =
            entries
                |> List.filter (\( t, _ ) -> t == team)
                |> List.head
                |> Maybe.map Tuple.second
    in
    describe "aggregate"
        [ test "empty list → empty list" <|
            \_ ->
                TrialResult.aggregate []
                    |> Expect.equal []
        , test "single result → two team entries" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5 ]
                in
                Expect.equal (List.length entries) 2
        , test "winner gets 1 win, 0 losses" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5 ]

                    record =
                        findRecord teamA entries
                in
                record
                    |> Maybe.map
                        (\r ->
                            ( Standings.wins r
                            , Standings.losses r
                            )
                        )
                    |> Expect.equal (Just ( 1, 0 ))
        , test "loser gets 0 wins, 1 loss" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5 ]

                    record =
                        findRecord teamB entries
                in
                record
                    |> Maybe.map
                        (\r ->
                            ( Standings.wins r
                            , Standings.losses r
                            )
                        )
                    |> Expect.equal (Just ( 0, 1 ))
        , test "pointsFor/Against correct for winner" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5 ]

                    record =
                        findRecord teamA entries
                in
                record
                    |> Maybe.map
                        (\r ->
                            ( Standings.pointsFor r
                            , Standings.pointsAgainst r
                            )
                        )
                    |> Expect.equal (Just ( 8, 5 ))
        , test "multiple results accumulate wins" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5
                            , mkResult teamA teamC 7 6
                            ]

                    record =
                        findRecord teamA entries
                in
                record
                    |> Maybe.map
                        (\r ->
                            ( Standings.wins r
                            , Standings.losses r
                            )
                        )
                    |> Expect.equal (Just ( 2, 0 ))
        , test "multiple results accumulate points" <|
            \_ ->
                let
                    entries =
                        TrialResult.aggregate
                            [ mkResult teamA teamB 8 5
                            , mkResult teamA teamC 7 6
                            ]

                    record =
                        findRecord teamA entries
                in
                record
                    |> Maybe.map
                        (\r ->
                            ( Standings.pointsFor r
                            , Standings.pointsAgainst r
                            )
                        )
                    |> Expect.equal (Just ( 15, 11 ))
        ]


headToHeadTests : Test
headToHeadTests =
    let
        mkResult pTeam dTeam pPts dPts =
            case
                trialResultFor pTeam dTeam pPts dPts
            of
                Ok r ->
                    r

                Err _ ->
                    Debug.todo "headToHead test result must be valid"
    in
    describe "headToHead"
        [ test "no shared history → 0/0" <|
            \_ ->
                TrialResult.headToHead teamA teamB []
                    |> Expect.equal { wins = 0, losses = 0 }
        , test "A beat B → { wins = 1, losses = 0 } for A" <|
            \_ ->
                TrialResult.headToHead teamA
                    teamB
                    [ mkResult teamA teamB 8 5 ]
                    |> Expect.equal { wins = 1, losses = 0 }
        , test "B beat A → { wins = 0, losses = 1 } for A" <|
            \_ ->
                TrialResult.headToHead teamA
                    teamB
                    [ mkResult teamB teamA 8 5 ]
                    |> Expect.equal { wins = 0, losses = 1 }
        , test "unrelated trials excluded" <|
            \_ ->
                TrialResult.headToHead teamA
                    teamB
                    [ mkResult teamA teamC 8 5 ]
                    |> Expect.equal { wins = 0, losses = 0 }
        ]



-- Helper: build a TrialResult for arbitrary teams


trialResultFor :
    Team
    -> Team
    -> Int
    -> Int
    -> Result (List Error) TrialResult.TrialResult
trialResultFor pTeam dTeam pPts dPts =
    let
        trial =
            trialFor pTeam dTeam
    in
    TrialResult.trialResult trial
        [ ballotWith pPts dPts ]
        Nothing
