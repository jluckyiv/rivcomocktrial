module PowerMatchTest exposing (..)

import Api exposing (Team, Trial)
import Expect
import PowerMatch
    exposing
        ( CrossBracketStrategy(..)
        , PowerMatchResult
        , ProposedPairing
        , RankedTeam
        , hasPlayed
        , powerMatch
        , sideHistory
        )
import PowerMatchFixtures as F
import Test exposing (Test, describe, test)


{-| Helper: collect all team IDs from pairings.
-}
pairedTeamIds : PowerMatchResult -> List String
pairedTeamIds result =
    List.concatMap
        (\p -> [ p.prosecutionTeam, p.defenseTeam ])
        result.pairings


-- SIDE HISTORY TESTS


sideHistoryTests : Test
sideHistoryTests =
    describe "sideHistory"
        [ test "counts prosecution and defense appearances" <|
            \_ ->
                let
                    trials =
                        F.trialsThrough 2

                    -- Team 09 (Notre Dame): R1 D, R2 P
                    sides =
                        sideHistory trials F.team09.id
                in
                Expect.equal
                    { prosecution = 1, defense = 1 }
                    sides
        , test "team with no trials has zero counts" <|
            \_ ->
                sideHistory [] "nonexistent"
                    |> Expect.equal { prosecution = 0, defense = 0 }
        , test "team 06 after R1: 1P 0D" <|
            \_ ->
                sideHistory F.round1Trials F.team06.id
                    |> Expect.equal { prosecution = 1, defense = 0 }
        , test "team 01 after R2: 1P 1D" <|
            \_ ->
                -- R1: defense, R2: prosecution
                sideHistory (F.trialsThrough 2) F.team01.id
                    |> Expect.equal { prosecution = 1, defense = 1 }
        ]



-- HAS PLAYED TESTS


hasPlayedTests : Test
hasPlayedTests =
    describe "hasPlayed"
        [ test "detects previous matchup (P vs D)" <|
            \_ ->
                -- R1: La Quinta (6) P vs Indio (15) D
                hasPlayed F.round1Trials F.team06.id F.team15.id
                    |> Expect.equal True
        , test "detects previous matchup (D vs P, reversed)" <|
            \_ ->
                hasPlayed F.round1Trials F.team15.id F.team06.id
                    |> Expect.equal True
        , test "returns False for teams that haven't played" <|
            \_ ->
                hasPlayed F.round1Trials F.team01.id F.team06.id
                    |> Expect.equal False
        ]



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
                        F.round1Trials
                        []
             in
             [ test "every team appears exactly once" <|
                \_ ->
                    let
                        ids =
                            pairedTeamIds result

                        expectedIds =
                            List.map .id F.allTeams
                    in
                    Expect.equal
                        (List.sort expectedIds)
                        (List.sort ids)
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
                                    hasPlayed F.round1Trials
                                        p.prosecutionTeam
                                        p.defenseTeam
                                )
                                result.pairings
                    in
                    hasRematch |> Expect.equal False
             , test "no team plays same side 3+ times" <|
                \_ ->
                    let
                        allTrials =
                            F.round1Trials
                                ++ List.map
                                    (\p ->
                                        F.makeTrial "" 2
                                            p.prosecutionTeam
                                            p.defenseTeam
                                    )
                                    result.pairings

                        sideViolation =
                            List.any
                                (\team ->
                                    let
                                        sides =
                                            sideHistory allTrials team.id
                                    in
                                    sides.prosecution >= 3
                                        || sides.defense >= 3
                                )
                                F.allTeams
                    in
                    sideViolation |> Expect.equal False
             , test "side switching: R1 P plays R2 D" <|
                \_ ->
                    let
                        -- Teams that played P in R1
                        r1ProsecutionIds =
                            List.map .prosecutionTeam F.round1Trials

                        -- Check they play D in R2
                        violations =
                            List.filter
                                (\p ->
                                    List.member p.prosecutionTeam
                                        r1ProsecutionIds
                                )
                                result.pairings
                    in
                    List.length violations
                        |> Expect.equal 0
             ]
            )
        , describe "R4 pairings"
            (let
                priorTrials =
                    F.trialsThrough 3

                result =
                    powerMatch HighHigh
                        rankedAfterR3
                        priorTrials
                        []
             in
             [ test "every team appears exactly once" <|
                \_ ->
                    let
                        ids =
                            pairedTeamIds result

                        expectedIds =
                            List.map .id F.allTeams
                    in
                    Expect.equal
                        (List.sort expectedIds)
                        (List.sort ids)
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
                                    hasPlayed priorTrials
                                        p.prosecutionTeam
                                        p.defenseTeam
                                )
                                result.pairings
                    in
                    hasRematch |> Expect.equal False
             , test "side switching: R3 P plays R4 D" <|
                \_ ->
                    let
                        r3ProsecutionIds =
                            List.map .prosecutionTeam F.round3Trials

                        violations =
                            List.filter
                                (\p ->
                                    List.member p.prosecutionTeam
                                        r3ProsecutionIds
                                )
                                result.pairings
                    in
                    List.length violations
                        |> Expect.equal 0
             , test "no team plays same side 3+ times" <|
                \_ ->
                    let
                        allTrials =
                            priorTrials
                                ++ List.map
                                    (\p ->
                                        F.makeTrial "" 4
                                            p.prosecutionTeam
                                            p.defenseTeam
                                    )
                                    result.pairings

                        sideViolation =
                            List.any
                                (\team ->
                                    let
                                        sides =
                                            sideHistory allTrials team.id
                                    in
                                    sides.prosecution >= 3
                                        || sides.defense >= 3
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
                    priorTrials =
                        F.trialsThrough 3

                    highHigh =
                        powerMatch HighHigh
                            rankedAfterR3
                            priorTrials
                            []

                    highLow =
                        powerMatch HighLow
                            rankedAfterR3
                            priorTrials
                            []
                in
                Expect.notEqual
                    highHigh.pairings
                    highLow.pairings
        , test "HighLow: no rematches" <|
            \_ ->
                let
                    priorTrials =
                        F.trialsThrough 3

                    result =
                        powerMatch HighLow
                            rankedAfterR3
                            priorTrials
                            []

                    hasRematch =
                        List.any
                            (\p ->
                                hasPlayed priorTrials
                                    p.prosecutionTeam
                                    p.defenseTeam
                            )
                            result.pairings
                in
                hasRematch |> Expect.equal False
        , test "HighLow: every team appears exactly once" <|
            \_ ->
                let
                    priorTrials =
                        F.trialsThrough 3

                    result =
                        powerMatch HighLow
                            rankedAfterR3
                            priorTrials
                            []

                    ids =
                        pairedTeamIds result

                    expectedIds =
                        List.map .id F.allTeams
                in
                Expect.equal
                    (List.sort expectedIds)
                    (List.sort ids)
        ]



-- REMATCH AVOIDANCE EDGE CASE


rematchAvoidanceTests : Test
rematchAvoidanceTests =
    describe "rematch avoidance"
        [ test "avoids rematch even when greedy choice would cause one" <|
            \_ ->
                -- Set up 4 teams where the naive greedy pairing
                -- (first with last) would force a rematch:
                -- A has played D, B has played C.
                -- Greedy top-bottom: A-D (rematch!), B-C (rematch!)
                -- Correct: A-C, B-D (or A-B with side swap)
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
                    priorTrials =
                        [ F.makeTrial "prev_1" 1 teamA.id teamD.id
                        , F.makeTrial "prev_2" 1 teamB.id teamC.id
                        ]

                    ranked =
                        [ { team = teamA, wins = 1, losses = 0, rank = 1 }
                        , { team = teamB, wins = 1, losses = 0, rank = 2 }
                        , { team = teamC, wins = 0, losses = 1, rank = 1 }
                        , { team = teamD, wins = 0, losses = 1, rank = 2 }
                        ]

                    result =
                        powerMatch HighHigh ranked priorTrials []

                    hasRematch =
                        List.any
                            (\p ->
                                hasPlayed priorTrials
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
                -- 6 teams, R1 pairings: A-B, C-D, E-F
                -- R2 with side switch: naive would pair
                -- B-A (rematch), D-C (rematch), F-E (rematch)
                -- Must find valid non-rematch arrangement
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

                    priorTrials =
                        [ F.makeTrial "p1" 1 teamA.id teamB.id
                        , F.makeTrial "p2" 1 teamC.id teamD.id
                        , F.makeTrial "p3" 1 teamE.id teamF.id
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
                        powerMatch HighHigh ranked priorTrials []

                    hasRematch =
                        List.any
                            (\p ->
                                hasPlayed priorTrials
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
