module StandingsTest exposing (suite)

import Expect
import Standings
    exposing
        ( TeamRecord
        , Tiebreaker(..)
        )
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Standings"
        [ cumulativePercentageSuite
        , rankSuite
        ]


cumulativePercentageSuite : Test
cumulativePercentageSuite =
    describe "cumulativePercentage"
        [ test "pointsFor / (pointsFor + pointsAgainst)" <|
            \_ ->
                { wins = 2, losses = 1, pointsFor = 300, pointsAgainst = 200 }
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 0.6
        , test "returns 0 when no points" <|
            \_ ->
                { wins = 0, losses = 0, pointsFor = 0, pointsAgainst = 0 }
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 0.0
        , test "100% when opponent scored 0" <|
            \_ ->
                { wins = 1, losses = 0, pointsFor = 100, pointsAgainst = 0 }
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 1.0
        ]


record : Int -> Int -> Int -> Int -> TeamRecord
record w l pf pa =
    { wins = w, losses = l, pointsFor = pf, pointsAgainst = pa }


rankSuite : Test
rankSuite =
    describe "rank"
        [ test "by ByWins — more wins ranked higher" <|
            \_ ->
                [ ( "B", record 1 2 200 300 )
                , ( "A", record 3 0 300 200 )
                ]
                    |> Standings.rank [ ByWins ]
                    |> List.map Tuple.first
                    |> Expect.equal [ "A", "B" ]
        , test "by ByCumulativePercentage — higher % first" <|
            \_ ->
                [ ( "B", record 1 1 200 300 )
                , ( "A", record 1 1 400 200 )
                ]
                    |> Standings.rank [ ByCumulativePercentage ]
                    |> List.map Tuple.first
                    |> Expect.equal [ "A", "B" ]
        , test "by ByPointDifferential — higher diff first" <|
            \_ ->
                [ ( "B", record 1 1 200 300 )
                , ( "A", record 1 1 400 200 )
                ]
                    |> Standings.rank [ ByPointDifferential ]
                    |> List.map Tuple.first
                    |> Expect.equal [ "A", "B" ]
        , test "strategy [ByWins, ByCumulativePercentage] — wins primary, % breaks ties" <|
            \_ ->
                [ ( "C", record 2 1 200 300 )
                , ( "A", record 2 1 400 200 )
                , ( "B", record 3 0 300 200 )
                ]
                    |> Standings.rank [ ByWins, ByCumulativePercentage ]
                    |> List.map Tuple.first
                    |> Expect.equal [ "B", "A", "C" ]
        , test "equal records maintain relative order" <|
            \_ ->
                [ ( "A", record 2 1 300 200 )
                , ( "B", record 2 1 300 200 )
                ]
                    |> Standings.rank [ ByWins, ByCumulativePercentage ]
                    |> List.map Tuple.first
                    |> Expect.equal [ "A", "B" ]
        ]
