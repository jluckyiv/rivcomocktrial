module PowerMatchTest exposing (..)

import Expect
import MatchHistory
import PowerMatch
    exposing
        ( CrossBracketStrategy(..)
        , PowerMatchResult
        , RankedTeam
        , powerMatch
        )
import PowerMatchFixtures as F
import Team exposing (Team)
import Test exposing (Test, describe, test)


{-| Helper: collect all team keys (numbers) from pairings.
-}
pairedTeamKeys : PowerMatchResult -> List Int
pairedTeamKeys result =
    List.concatMap
        (\p ->
            [ teamKey p.prosecutionTeam
            , teamKey p.defenseTeam
            ]
        )
        result.pairings


teamKey : Team -> Int
teamKey team =
    Team.numberToInt (Team.teamNumber team)



-- STRUCTURAL INVARIANT TESTS


{-| Build ranked teams after R1 for R2 power matching.
Winners (1-0): 1, 2, 4, 8, 9, 12, 13, 15, 16, 20, 22, 25, 27
Losers (0-1): 3, 5, 6, 10, 11, 14, 17, 19, 21, 23, 24, 26, 28
-}
rankedAfterR1 : List RankedTeam
rankedAfterR1 =
    [ F.makeRankedTeam 1 "Palm Desert" 1 0 1
    , F.makeRankedTeam 2 "Santiago" 1 0 2
    , F.makeRankedTeam 4 "Murrieta Valley" 1 0 3
    , F.makeRankedTeam 8 "Norco" 1 0 4
    , F.makeRankedTeam 9 "Notre Dame" 1 0 5
    , F.makeRankedTeam 12 "Temecula Valley" 1 0 6
    , F.makeRankedTeam 13 "Poly" 1 0 7
    , F.makeRankedTeam 15 "Indio" 1 0 8
    , F.makeRankedTeam 16 "Ramona" 1 0 9
    , F.makeRankedTeam 20 "Hemet" 1 0 10
    , F.makeRankedTeam 22 "Chaparral" 1 0 11
    , F.makeRankedTeam 25 "St. Jeanne de Lestonnac" 1 0 12
    , F.makeRankedTeam 27 "Martin Luther King" 1 0 13
    , F.makeRankedTeam 3 "Vista del Lago" 0 1 1
    , F.makeRankedTeam 5 "Patriot" 0 1 2
    , F.makeRankedTeam 6 "La Quinta" 0 1 3
    , F.makeRankedTeam 10 "Valley View" 0 1 4
    , F.makeRankedTeam 11 "Canyon Springs" 0 1 5
    , F.makeRankedTeam 14 "Heritage" 0 1 6
    , F.makeRankedTeam 17 "Liberty" 0 1 7
    , F.makeRankedTeam 19 "John W. North" 0 1 8
    , F.makeRankedTeam 21 "Great Oak" 0 1 9
    , F.makeRankedTeam 23 "Paloma Valley" 0 1 10
    , F.makeRankedTeam 24 "Palo Verde" 0 1 11
    , F.makeRankedTeam 26 "Centennial" 0 1 12
    , F.makeRankedTeam 28 "San Jacinto" 0 1 13
    ]


{-| Ranked teams after R3 for R4 power matching.
3-0: 1, 9, 12, 13
2-1: 2, 5, 10, 15, 16, 20, 22, 25, 27
1-2: 4, 6, 8, 11, 19, 21, 23, 26, 28
0-3: 3, 14, 17, 24
-}
rankedAfterR3 : List RankedTeam
rankedAfterR3 =
    [ F.makeRankedTeam 1 "Palm Desert" 3 0 1
    , F.makeRankedTeam 9 "Notre Dame" 3 0 2
    , F.makeRankedTeam 12 "Temecula Valley" 3 0 3
    , F.makeRankedTeam 13 "Poly" 3 0 4
    , F.makeRankedTeam 2 "Santiago" 2 1 1
    , F.makeRankedTeam 5 "Patriot" 2 1 2
    , F.makeRankedTeam 10 "Valley View" 2 1 3
    , F.makeRankedTeam 15 "Indio" 2 1 4
    , F.makeRankedTeam 16 "Ramona" 2 1 5
    , F.makeRankedTeam 20 "Hemet" 2 1 6
    , F.makeRankedTeam 22 "Chaparral" 2 1 7
    , F.makeRankedTeam 25 "St. Jeanne de Lestonnac" 2 1 8
    , F.makeRankedTeam 27 "Martin Luther King" 2 1 9
    , F.makeRankedTeam 4 "Murrieta Valley" 1 2 1
    , F.makeRankedTeam 6 "La Quinta" 1 2 2
    , F.makeRankedTeam 8 "Norco" 1 2 3
    , F.makeRankedTeam 11 "Canyon Springs" 1 2 4
    , F.makeRankedTeam 19 "John W. North" 1 2 5
    , F.makeRankedTeam 21 "Great Oak" 1 2 6
    , F.makeRankedTeam 23 "Paloma Valley" 1 2 7
    , F.makeRankedTeam 26 "Centennial" 1 2 8
    , F.makeRankedTeam 28 "San Jacinto" 1 2 9
    , F.makeRankedTeam 3 "Vista del Lago" 0 3 1
    , F.makeRankedTeam 14 "Heritage" 0 3 2
    , F.makeRankedTeam 17 "Liberty" 0 3 3
    , F.makeRankedTeam 24 "Palo Verde" 0 3 4
    ]


structuralInvariantTests : Test
structuralInvariantTests =
    describe "structural invariants"
        [ describe "R2 pairings"
            (let
                result =
                    powerMatch HighHigh
                        rankedAfterR1
                        F.round1History
                        MatchHistory.empty
             in
             [ test "every team appears exactly once" <|
                \_ ->
                    let
                        keys =
                            pairedTeamKeys result

                        expectedKeys =
                            List.map teamKey F.allTeams
                    in
                    Expect.equal
                        (List.sort expectedKeys)
                        (List.sort keys)
             , test "produces 13 pairings for 26 teams" <|
                \_ ->
                    List.length result.pairings
                        |> Expect.equal 13
             , test "no rematches against R1 opponents" <|
                \_ ->
                    let
                        hasRematch =
                            List.any
                                (\p ->
                                    MatchHistory.hasPlayed F.round1History
                                        p.prosecutionTeam
                                        p.defenseTeam
                                )
                                result.pairings
                    in
                    hasRematch |> Expect.equal False
             , test "no team plays same side 3+ times" <|
                \_ ->
                    let
                        allHistory =
                            MatchHistory.fromRecords
                                (MatchHistory.toRecords F.round1History
                                    ++ List.map
                                        (\p ->
                                            { prosecution = p.prosecutionTeam
                                            , defense = p.defenseTeam
                                            }
                                        )
                                        result.pairings
                                )

                        sideViolation =
                            List.any
                                (\team ->
                                    let
                                        sides =
                                            MatchHistory.sideHistory allHistory team
                                    in
                                    sides.prosecution
                                        >= 3
                                        || sides.defense
                                        >= 3
                                )
                                F.allTeams
                    in
                    sideViolation |> Expect.equal False
             , test "side switching: R1 P plays R2 D" <|
                \_ ->
                    let
                        -- Teams that played P in R1
                        r1ProsecutionKeys =
                            List.map
                                (\r -> teamKey r.prosecution)
                                (MatchHistory.toRecords F.round1History)

                        -- Check they play D in R2
                        violations =
                            List.filter
                                (\p ->
                                    List.member
                                        (teamKey p.prosecutionTeam)
                                        r1ProsecutionKeys
                                )
                                result.pairings
                    in
                    List.length violations
                        |> Expect.equal 0
             ]
            )
        , describe "R4 pairings"
            (let
                priorHistory =
                    F.historyThrough 3

                result =
                    powerMatch HighHigh
                        rankedAfterR3
                        priorHistory
                        MatchHistory.empty
             in
             [ test "every team appears exactly once" <|
                \_ ->
                    let
                        keys =
                            pairedTeamKeys result

                        expectedKeys =
                            List.map teamKey F.allTeams
                    in
                    Expect.equal
                        (List.sort expectedKeys)
                        (List.sort keys)
             , test "produces 13 pairings" <|
                \_ ->
                    List.length result.pairings
                        |> Expect.equal 13
             , test "no rematches against R1-R3 opponents" <|
                \_ ->
                    let
                        hasRematch =
                            List.any
                                (\p ->
                                    MatchHistory.hasPlayed priorHistory
                                        p.prosecutionTeam
                                        p.defenseTeam
                                )
                                result.pairings
                    in
                    hasRematch |> Expect.equal False
             , test "side switching: R3 P plays R4 D" <|
                \_ ->
                    let
                        r3ProsecutionKeys =
                            List.map
                                (\r -> teamKey r.prosecution)
                                (MatchHistory.toRecords F.round3History)

                        violations =
                            List.filter
                                (\p ->
                                    List.member
                                        (teamKey p.prosecutionTeam)
                                        r3ProsecutionKeys
                                )
                                result.pairings
                    in
                    List.length violations
                        |> Expect.equal 0
             , test "no team plays same side 3+ times" <|
                \_ ->
                    let
                        allHistory =
                            MatchHistory.fromRecords
                                (MatchHistory.toRecords priorHistory
                                    ++ List.map
                                        (\p ->
                                            { prosecution = p.prosecutionTeam
                                            , defense = p.defenseTeam
                                            }
                                        )
                                        result.pairings
                                )

                        sideViolation =
                            List.any
                                (\team ->
                                    let
                                        sides =
                                            MatchHistory.sideHistory allHistory team
                                    in
                                    sides.prosecution
                                        >= 3
                                        || sides.defense
                                        >= 3
                                )
                                F.allTeams
                    in
                    sideViolation |> Expect.equal False
             ]
            )
        ]



-- CROSS-BRACKET STRATEGY TESTS


crossBracketStrategyTests : Test
crossBracketStrategyTests =
    describe "cross-bracket strategy"
        [ test "HighHigh and HighLow produce different pairings for R4" <|
            \_ ->
                let
                    priorHistory =
                        F.historyThrough 3

                    highHigh =
                        powerMatch HighHigh
                            rankedAfterR3
                            priorHistory
                            MatchHistory.empty

                    highLow =
                        powerMatch HighLow
                            rankedAfterR3
                            priorHistory
                            MatchHistory.empty
                in
                Expect.notEqual
                    (List.map (\p -> ( teamKey p.prosecutionTeam, teamKey p.defenseTeam )) highHigh.pairings)
                    (List.map (\p -> ( teamKey p.prosecutionTeam, teamKey p.defenseTeam )) highLow.pairings)
        , test "HighLow: no rematches" <|
            \_ ->
                let
                    priorHistory =
                        F.historyThrough 3

                    result =
                        powerMatch HighLow
                            rankedAfterR3
                            priorHistory
                            MatchHistory.empty

                    hasRematch =
                        List.any
                            (\p ->
                                MatchHistory.hasPlayed priorHistory
                                    p.prosecutionTeam
                                    p.defenseTeam
                            )
                            result.pairings
                in
                hasRematch |> Expect.equal False
        , test "HighLow: every team appears exactly once" <|
            \_ ->
                let
                    priorHistory =
                        F.historyThrough 3

                    result =
                        powerMatch HighLow
                            rankedAfterR3
                            priorHistory
                            MatchHistory.empty

                    keys =
                        pairedTeamKeys result

                    expectedKeys =
                        List.map teamKey F.allTeams
                in
                Expect.equal
                    (List.sort expectedKeys)
                    (List.sort keys)
        ]



-- REMATCH AVOIDANCE EDGE CASE


rematchAvoidanceTests : Test
rematchAvoidanceTests =
    describe "rematch avoidance"
        [ test "avoids rematch even when greedy choice would cause one" <|
            \_ ->
                let
                    teamA =
                        F.makeTeam 90 "Team A"

                    teamB =
                        F.makeTeam 91 "Team B"

                    teamC =
                        F.makeTeam 92 "Team C"

                    teamD =
                        F.makeTeam 93 "Team D"

                    -- A played D in R1, B played C in R1
                    priorHistory =
                        MatchHistory.fromRecords
                            [ { prosecution = teamA, defense = teamD }
                            , { prosecution = teamB, defense = teamC }
                            ]

                    ranked =
                        [ { team = teamA, wins = 1, losses = 0, rank = 1 }
                        , { team = teamB, wins = 1, losses = 0, rank = 2 }
                        , { team = teamC, wins = 0, losses = 1, rank = 1 }
                        , { team = teamD, wins = 0, losses = 1, rank = 2 }
                        ]

                    result =
                        powerMatch HighHigh ranked priorHistory MatchHistory.empty

                    hasRematch =
                        List.any
                            (\p ->
                                MatchHistory.hasPlayed priorHistory
                                    p.prosecutionTeam
                                    p.defenseTeam
                            )
                            result.pairings
                in
                Expect.all
                    [ \r -> List.length r.pairings |> Expect.equal 2
                    , \_ -> hasRematch |> Expect.equal False
                    ]
                    result
        , test "avoids rematch with 6 teams and constrained history" <|
            \_ ->
                let
                    teamA =
                        F.makeTeam 80 "Team A"

                    teamB =
                        F.makeTeam 81 "Team B"

                    teamC =
                        F.makeTeam 82 "Team C"

                    teamD =
                        F.makeTeam 83 "Team D"

                    teamE =
                        F.makeTeam 84 "Team E"

                    teamF =
                        F.makeTeam 85 "Team F"

                    priorHistory =
                        MatchHistory.fromRecords
                            [ { prosecution = teamA, defense = teamB }
                            , { prosecution = teamC, defense = teamD }
                            , { prosecution = teamE, defense = teamF }
                            ]

                    ranked =
                        [ { team = teamA, wins = 1, losses = 0, rank = 1 }
                        , { team = teamC, wins = 1, losses = 0, rank = 2 }
                        , { team = teamE, wins = 1, losses = 0, rank = 3 }
                        , { team = teamB, wins = 0, losses = 1, rank = 1 }
                        , { team = teamD, wins = 0, losses = 1, rank = 2 }
                        , { team = teamF, wins = 0, losses = 1, rank = 3 }
                        ]

                    result =
                        powerMatch HighHigh ranked priorHistory MatchHistory.empty

                    hasRematch =
                        List.any
                            (\p ->
                                MatchHistory.hasPlayed priorHistory
                                    p.prosecutionTeam
                                    p.defenseTeam
                            )
                            result.pairings
                in
                Expect.all
                    [ \r -> List.length r.pairings |> Expect.equal 3
                    , \_ -> hasRematch |> Expect.equal False
                    ]
                    result
        ]
