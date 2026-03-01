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
        [ teamRecordSuite
        , cumulativePercentageSuite
        , rankSuite
        ]


record : Int -> Int -> Int -> Int -> TeamRecord
record w l pf pa =
    Standings.teamRecord
        { wins = w, losses = l, pointsFor = pf, pointsAgainst = pa }


teamRecordSuite : Test
teamRecordSuite =
    describe "teamRecord"
        [ test "wins accessor" <|
            \_ ->
                record 3 1 300 200
                    |> Standings.wins
                    |> Expect.equal 3
        , test "losses accessor" <|
            \_ ->
                record 3 1 300 200
                    |> Standings.losses
                    |> Expect.equal 1
        , test "pointsFor accessor" <|
            \_ ->
                record 3 1 300 200
                    |> Standings.pointsFor
                    |> Expect.equal 300
        , test "pointsAgainst accessor" <|
            \_ ->
                record 3 1 300 200
                    |> Standings.pointsAgainst
                    |> Expect.equal 200
        ]


cumulativePercentageSuite : Test
cumulativePercentageSuite =
    describe "cumulativePercentage"
        [ test "pointsFor / (pointsFor + pointsAgainst)" <|
            \_ ->
                record 2 1 300 200
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 0.6
        , test "returns 0 when no points" <|
            \_ ->
                record 0 0 0 0
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 0.0
        , test "100% when opponent scored 0" <|
            \_ ->
                record 1 0 100 0
                    |> Standings.cumulativePercentage
                    |> Expect.within (Expect.Absolute 0.001) 1.0
        ]


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
