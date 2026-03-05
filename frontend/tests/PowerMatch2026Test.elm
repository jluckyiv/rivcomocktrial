module PowerMatch2026Test exposing (..)

import Expect
import MatchHistory exposing (MatchHistory, MatchRecord)
import PowerMatch
    exposing
        ( CrossBracketStrategy(..)
        , powerMatch
        )
import PowerMatchFixtures as F
import Team exposing (Team)
import Test exposing (Test, describe, test)


teamKey : Team -> Int
teamKey team =
    Team.numberToInt (Team.teamNumber team)


{-| Tests that validate the 2026 competition data against
the published rules. These serve two purposes:

1.  Verify the fixture data is correctly transcribed from
    the official pairing sheets and result PDFs.
2.  Confirm that the actual 2026 pairings satisfy every
    structural constraint the PowerMatch module enforces.

-}



-- SIDE BALANCE ACROSS ALL 4 ROUNDS


sideBalanceTests : Test
sideBalanceTests =
    describe "2026 side balance"
        [ test "every team plays prosecution exactly 2 times" <|
            \_ ->
                let
                    allHistory =
                        F.historyThrough 4

                    violations =
                        List.filter
                            (\team ->
                                let
                                    sides =
                                        MatchHistory.sideHistory allHistory team
                                in
                                sides.prosecution /= 2
                            )
                            F.allTeams
                in
                violations
                    |> List.map teamKey
                    |> Expect.equal []
        , test "every team plays defense exactly 2 times" <|
            \_ ->
                let
                    allHistory =
                        F.historyThrough 4

                    violations =
                        List.filter
                            (\team ->
                                let
                                    sides =
                                        MatchHistory.sideHistory allHistory team
                                in
                                sides.defense /= 2
                            )
                            F.allTeams
                in
                violations
                    |> List.map teamKey
                    |> Expect.equal []
        ]



-- NO REMATCHES


noRematchTests : Test
noRematchTests =
    describe "2026 no rematches"
        [ test "R2 has no rematches from R1" <|
            \_ ->
                rematches F.round1History F.round2History
                    |> Expect.equal []
        , test "R3 has no rematches from R1-R2" <|
            \_ ->
                rematches (F.historyThrough 2) F.round3History
                    |> Expect.equal []
        , test "R4 has no rematches from R1-R3" <|
            \_ ->
                rematches (F.historyThrough 3) F.round4History
                    |> Expect.equal []
        , test "no team faces the same opponent twice across all 4 rounds" <|
            \_ ->
                let
                    allRecords =
                        MatchHistory.toRecords (F.historyThrough 4)

                    matchups =
                        List.map
                            (\r ->
                                normalizeMatchup
                                    (teamKey r.prosecution)
                                    (teamKey r.defense)
                            )
                            allRecords

                    duplicates =
                        findDuplicates matchups
                in
                duplicates |> Expect.equal []
        ]


{-| Return list of matchup descriptions that are rematches.
-}
rematches : MatchHistory -> MatchHistory -> List String
rematches priorHistory roundHistory =
    List.filterMap
        (\r ->
            if MatchHistory.hasPlayed priorHistory r.prosecution r.defense then
                Just
                    (String.fromInt (teamKey r.prosecution)
                        ++ " vs "
                        ++ String.fromInt (teamKey r.defense)
                    )

            else
                Nothing
        )
        (MatchHistory.toRecords roundHistory)



-- SIDE SWITCHING


sideSwitchingTests : Test
sideSwitchingTests =
    describe "2026 side switching"
        [ test "R1 prosecution teams play R2 defense" <|
            \_ ->
                let
                    r1ProsecutionKeys =
                        List.map
                            (\r -> teamKey r.prosecution)
                            (MatchHistory.toRecords F.round1History)

                    -- These teams should appear as defense in R2
                    violations =
                        List.filter
                            (\r ->
                                List.member
                                    (teamKey r.prosecution)
                                    r1ProsecutionKeys
                            )
                            (MatchHistory.toRecords F.round2History)
                in
                violations
                    |> List.map (\r -> teamKey r.prosecution)
                    |> Expect.equal []
        , test "R1 defense teams play R2 prosecution" <|
            \_ ->
                let
                    r1DefenseKeys =
                        List.map
                            (\r -> teamKey r.defense)
                            (MatchHistory.toRecords F.round1History)

                    -- These teams should appear as prosecution in R2
                    violations =
                        List.filter
                            (\r ->
                                List.member
                                    (teamKey r.defense)
                                    r1DefenseKeys
                            )
                            (MatchHistory.toRecords F.round2History)
                in
                violations
                    |> List.map (\r -> teamKey r.defense)
                    |> Expect.equal []
        , test "R3 prosecution teams play R4 defense" <|
            \_ ->
                let
                    r3ProsecutionKeys =
                        List.map
                            (\r -> teamKey r.prosecution)
                            (MatchHistory.toRecords F.round3History)

                    violations =
                        List.filter
                            (\r ->
                                List.member
                                    (teamKey r.prosecution)
                                    r3ProsecutionKeys
                            )
                            (MatchHistory.toRecords F.round4History)
                in
                violations
                    |> List.map (\r -> teamKey r.prosecution)
                    |> Expect.equal []
        , test "R3 defense teams play R4 prosecution" <|
            \_ ->
                let
                    r3DefenseKeys =
                        List.map
                            (\r -> teamKey r.defense)
                            (MatchHistory.toRecords F.round3History)

                    violations =
                        List.filter
                            (\r ->
                                List.member
                                    (teamKey r.defense)
                                    r3DefenseKeys
                            )
                            (MatchHistory.toRecords F.round4History)
                in
                violations
                    |> List.map (\r -> teamKey r.defense)
                    |> Expect.equal []
        ]



-- BRACKET PLACEMENT


bracketTests : Test
bracketTests =
    describe "2026 bracket placement"
        [ test "R3 pairings are all within-bracket (0 cross-bracket)" <|
            \_ ->
                let
                    winsAfterR2 =
                        countWins (F.historyThrough 2)

                    crossBracket =
                        List.filter
                            (\r ->
                                let
                                    pWins =
                                        getWins winsAfterR2 r.prosecution

                                    dWins =
                                        getWins winsAfterR2 r.defense
                                in
                                pWins /= dWins
                            )
                            (MatchHistory.toRecords F.round3History)
                in
                List.length crossBracket
                    |> Expect.equal 0
        , test "R2 has 7 cross-bracket pairings" <|
            \_ ->
                let
                    winsAfterR1 =
                        countWins F.round1History

                    crossBracket =
                        List.filter
                            (\r ->
                                let
                                    pWins =
                                        getWins winsAfterR1 r.prosecution

                                    dWins =
                                        getWins winsAfterR1 r.defense
                                in
                                pWins /= dWins
                            )
                            (MatchHistory.toRecords F.round2History)
                in
                List.length crossBracket
                    |> Expect.equal 7
        , test "R4 has 8 cross-bracket pairings" <|
            \_ ->
                let
                    winsAfterR3 =
                        countWins (F.historyThrough 3)

                    crossBracket =
                        List.filter
                            (\r ->
                                let
                                    pWins =
                                        getWins winsAfterR3 r.prosecution

                                    dWins =
                                        getWins winsAfterR3 r.defense
                                in
                                pWins /= dWins
                            )
                            (MatchHistory.toRecords F.round4History)
                in
                List.length crossBracket
                    |> Expect.equal 8
        ]



-- TRIAL COUNTS


trialCountTests : Test
trialCountTests =
    describe "2026 trial counts"
        [ test "13 trials per round" <|
            \_ ->
                [ List.length (MatchHistory.toRecords F.round1History)
                , List.length (MatchHistory.toRecords F.round2History)
                , List.length (MatchHistory.toRecords F.round3History)
                , List.length (MatchHistory.toRecords F.round4History)
                ]
                    |> Expect.equal [ 13, 13, 13, 13 ]
        , test "every team plays exactly 4 trials total" <|
            \_ ->
                let
                    allRecords =
                        MatchHistory.toRecords (F.historyThrough 4)

                    violations =
                        List.filter
                            (\team ->
                                let
                                    count =
                                        List.length
                                            (List.filter
                                                (\r ->
                                                    Team.sameTeam r.prosecution team
                                                        || Team.sameTeam r.defense team
                                                )
                                                allRecords
                                            )
                                in
                                count /= 4
                            )
                            F.allTeams
                in
                violations
                    |> List.map teamKey
                    |> Expect.equal []
        , test "26 unique teams across all trials" <|
            \_ ->
                let
                    allRecords =
                        MatchHistory.toRecords (F.historyThrough 4)

                    allKeys =
                        List.concatMap
                            (\r ->
                                [ teamKey r.prosecution
                                , teamKey r.defense
                                ]
                            )
                            allRecords

                    unique =
                        removeDuplicates allKeys
                in
                List.length unique
                    |> Expect.equal 26
        ]



-- WIN/LOSS RECORDS


winLossTests : Test
winLossTests =
    describe "2026 win/loss records"
        [ test "standings after R1: 13 winners, 13 losers" <|
            \_ ->
                let
                    wins =
                        countWins F.round1History

                    oneWin =
                        List.filter
                            (\team -> getWins wins team == 1)
                            F.allTeams

                    zeroWins =
                        List.filter
                            (\team -> getWins wins team == 0)
                            F.allTeams
                in
                ( List.length oneWin, List.length zeroWins )
                    |> Expect.equal ( 13, 13 )
        , test "R1 winners are teams 1,2,4,8,9,12,13,15,16,20,22,25,27" <|
            \_ ->
                let
                    wins =
                        countWins F.round1History

                    winners =
                        F.allTeams
                            |> List.filter
                                (\t -> getWins wins t == 1)
                            |> List.map teamKey
                            |> List.sort
                in
                winners
                    |> Expect.equal
                        [ 1, 2, 4, 8, 9, 12, 13
                        , 15, 16, 20, 22, 25, 27
                        ]
        , test "standings after R4: 2 at 4-0, 7 at 3-1, 9 at 2-2, 5 at 1-3, 3 at 0-4" <|
            \_ ->
                let
                    wins =
                        countWins (F.historyThrough 4)

                    byRecord =
                        List.map
                            (\w ->
                                List.length
                                    (List.filter
                                        (\t -> getWins wins t == w)
                                        F.allTeams
                                    )
                            )
                            [ 4, 3, 2, 1, 0 ]
                in
                byRecord |> Expect.equal [ 2, 7, 9, 5, 3 ]
        , test "4-0 teams are Notre Dame (9) and Poly (13)" <|
            \_ ->
                let
                    wins =
                        countWins (F.historyThrough 4)

                    fourOh =
                        F.allTeams
                            |> List.filter
                                (\t -> getWins wins t == 4)
                            |> List.map teamKey
                            |> List.sort
                in
                fourOh |> Expect.equal [ 9, 13 ]
        ]



-- REMATCH AVOIDANCE: CHAPARRAL (22) vs RAMONA (16)


chaparralRematchTests : Test
chaparralRematchTests =
    describe "2026 R4: Chaparral moved to avoid Ramona rematch"
        [ test "Ramona (16) and Chaparral (22) played in R2" <|
            \_ ->
                MatchHistory.hasPlayed F.round2History F.team16 F.team22
                    |> Expect.equal True
        , test "both are 2-1 going into R4" <|
            \_ ->
                let
                    wins =
                        countWins (F.historyThrough 3)

                    ramonaWins =
                        getWins wins F.team16

                    chaparralWins =
                        getWins wins F.team22
                in
                ( ramonaWins, chaparralWins )
                    |> Expect.equal ( 2, 2 )
        , test "Ramona needs P in R4 (played D in R3)" <|
            \_ ->
                let
                    sides =
                        MatchHistory.sideHistory F.round3History F.team16
                in
                sides |> Expect.equal { prosecution = 0, defense = 1 }
        , test "Chaparral needs D in R4 (played P in R3)" <|
            \_ ->
                let
                    sides =
                        MatchHistory.sideHistory F.round3History F.team22
                in
                sides |> Expect.equal { prosecution = 1, defense = 0 }
        , test "without the R2 matchup, they would be paired" <|
            \_ ->
                let
                    ranked =
                        [ F.makeRankedTeam 16 "Ramona" 2 1 1
                        , F.makeRankedTeam 22 "Chaparral" 2 1 2
                        ]

                    -- R3 sides only (no R2 matchup between them)
                    priorHistory =
                        MatchHistory.fromRecords
                            [ -- Ramona played D in R3 -> needs P
                              { prosecution = F.team19, defense = F.team16 }

                            -- Chaparral played P in R3 -> needs D
                            , { prosecution = F.team22, defense = F.team09 }
                            ]

                    result =
                        powerMatch HighHigh ranked priorHistory MatchHistory.empty

                    paired =
                        List.any
                            (\p ->
                                Team.sameTeam p.prosecutionTeam F.team16
                                    && Team.sameTeam p.defenseTeam F.team22
                            )
                            result.pairings
                in
                paired |> Expect.equal True
        , test "the R2 matchup prevents that pairing" <|
            \_ ->
                let
                    ranked =
                        [ F.makeRankedTeam 16 "Ramona" 2 1 1
                        , F.makeRankedTeam 22 "Chaparral" 2 1 2
                        ]

                    priorHistory =
                        MatchHistory.fromRecords
                            [ { prosecution = F.team19, defense = F.team16 }
                            , { prosecution = F.team22, defense = F.team09 }

                            -- The R2 rematch
                            , { prosecution = F.team16, defense = F.team22 }
                            ]

                    result =
                        powerMatch HighHigh ranked priorHistory MatchHistory.empty
                in
                -- Can't pair them — only 2 teams and they're
                -- a rematch, so zero pairings produced
                List.length result.pairings
                    |> Expect.equal 0
        , test "powerMatch does not pair Ramona with Chaparral in R4" <|
            \_ ->
                let
                    priorHistory =
                        F.historyThrough 3

                    ranked =
                        rankedAfterR3

                    result =
                        powerMatch HighHigh ranked priorHistory MatchHistory.empty

                    pairsRamonaWithChaparral =
                        List.any
                            (\p ->
                                (Team.sameTeam p.prosecutionTeam F.team16
                                    && Team.sameTeam p.defenseTeam F.team22
                                )
                                    || (Team.sameTeam p.prosecutionTeam F.team22
                                            && Team.sameTeam p.defenseTeam F.team16
                                       )
                            )
                            result.pairings
                in
                pairsRamonaWithChaparral |> Expect.equal False
        , test "powerMatch does not pair Ramona with Chaparral under HighLow either" <|
            \_ ->
                let
                    priorHistory =
                        F.historyThrough 3

                    ranked =
                        rankedAfterR3

                    result =
                        powerMatch HighLow ranked priorHistory MatchHistory.empty

                    pairsRamonaWithChaparral =
                        List.any
                            (\p ->
                                (Team.sameTeam p.prosecutionTeam F.team16
                                    && Team.sameTeam p.defenseTeam F.team22
                                )
                                    || (Team.sameTeam p.prosecutionTeam F.team22
                                            && Team.sameTeam p.defenseTeam F.team16
                                       )
                            )
                            result.pairings
                in
                pairsRamonaWithChaparral |> Expect.equal False
        ]


{-| Ranked teams after R3 for R4 power matching.
3-0: 1, 9, 12, 13
2-1: 2, 5, 10, 15, 16, 20, 22, 25, 27
1-2: 4, 6, 8, 11, 19, 21, 23, 26, 28
0-3: 3, 14, 17, 24
-}
rankedAfterR3 : List PowerMatch.RankedTeam
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



-- HELPERS


{-| Count wins for each team based on known 2026 results.
Returns a list of (team key, win count) pairs.
-}
countWins : MatchHistory -> List ( Int, Int )
countWins history =
    let
        records =
            MatchHistory.toRecords history

        allTeamKeys =
            List.concatMap
                (\r ->
                    [ teamKey r.prosecution
                    , teamKey r.defense
                    ]
                )
                records
                |> removeDuplicates

        winCount key =
            List.length
                (List.filter
                    (\r -> isWinner r key)
                    records
                )
    in
    List.map (\key -> ( key, winCount key )) allTeamKeys


{-| Determine if a team won a trial based on the known
2026 results.
-}
isWinner : MatchRecord -> Int -> Bool
isWinner record key =
    case recordWinner record of
        Just winnerKey ->
            winnerKey == key

        Nothing ->
            False


{-| Return the winner's team key for a known trial.
Maps each fixture trial (by prosecution/defense team keys)
to the winning team based on the 2026 official results.
-}
recordWinner : MatchRecord -> Maybe Int
recordWinner record =
    let
        pKey =
            teamKey record.prosecution

        dKey =
            teamKey record.defense

        pWins =
            Just pKey

        dWins =
            Just dKey
    in
    -- Identify by (prosecution, defense) team numbers
    case ( pKey, dKey ) of
        -- Round 1
        ( 6, 15 ) ->
            dWins

        ( 24, 1 ) ->
            dWins

        ( 19, 9 ) ->
            dWins

        ( 8, 11 ) ->
            pWins

        ( 5, 27 ) ->
            dWins

        ( 26, 13 ) ->
            dWins

        ( 10, 2 ) ->
            dWins

        ( 3, 16 ) ->
            dWins

        ( 4, 14 ) ->
            pWins

        ( 28, 25 ) ->
            dWins

        ( 22, 17 ) ->
            pWins

        ( 21, 12 ) ->
            dWins

        ( 23, 20 ) ->
            dWins

        -- Round 2
        ( 9, 23 ) ->
            pWins

        ( 2, 19 ) ->
            dWins

        ( 27, 21 ) ->
            pWins

        ( 16, 22 ) ->
            dWins

        ( 13, 4 ) ->
            pWins

        ( 12, 6 ) ->
            pWins

        ( 25, 3 ) ->
            pWins

        ( 15, 5 ) ->
            dWins

        ( 11, 24 ) ->
            pWins

        ( 20, 26 ) ->
            pWins

        ( 14, 28 ) ->
            dWins

        ( 17, 10 ) ->
            dWins

        ( 1, 8 ) ->
            pWins

        -- Round 3
        ( 25, 1 ) ->
            dWins

        ( 28, 5 ) ->
            dWins

        ( 23, 17 ) ->
            pWins

        ( 20, 12 ) ->
            dWins

        ( 6, 3 ) ->
            pWins

        ( 4, 2 ) ->
            dWins

        ( 26, 14 ) ->
            pWins

        ( 10, 8 ) ->
            pWins

        ( 19, 16 ) ->
            dWins

        ( 22, 9 ) ->
            dWins

        ( 21, 24 ) ->
            pWins

        ( 15, 11 ) ->
            pWins

        ( 27, 13 ) ->
            dWins

        -- Round 4
        ( 2, 15 ) ->
            pWins

        ( 16, 25 ) ->
            pWins

        ( 13, 21 ) ->
            pWins

        ( 24, 26 ) ->
            dWins

        ( 12, 22 ) ->
            dWins

        ( 11, 28 ) ->
            pWins

        ( 5, 10 ) ->
            dWins

        ( 1, 27 ) ->
            dWins

        ( 3, 23 ) ->
            dWins

        ( 8, 4 ) ->
            dWins

        ( 14, 6 ) ->
            pWins

        ( 17, 19 ) ->
            dWins

        ( 9, 20 ) ->
            pWins

        _ ->
            Nothing


getWins : List ( Int, Int ) -> Team -> Int
getWins winList team =
    let
        key =
            teamKey team
    in
    List.filter (\( k, _ ) -> k == key) winList
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault 0


normalizeMatchup : Int -> Int -> ( Int, Int )
normalizeMatchup a b =
    if a < b then
        ( a, b )

    else
        ( b, a )


findDuplicates : List ( Int, Int ) -> List ( Int, Int )
findDuplicates matchups =
    findDuplicatesHelper matchups [] []


findDuplicatesHelper :
    List ( Int, Int )
    -> List ( Int, Int )
    -> List ( Int, Int )
    -> List ( Int, Int )
findDuplicatesHelper remaining seen dupes =
    case remaining of
        [] ->
            dupes

        m :: rest ->
            if List.member m seen then
                findDuplicatesHelper rest seen (m :: dupes)

            else
                findDuplicatesHelper rest (m :: seen) dupes


removeDuplicates : List Int -> List Int
removeDuplicates items =
    removeDuplicatesHelper items []


removeDuplicatesHelper : List Int -> List Int -> List Int
removeDuplicatesHelper remaining acc =
    case remaining of
        [] ->
            List.reverse acc

        x :: rest ->
            if List.member x acc then
                removeDuplicatesHelper rest acc

            else
                removeDuplicatesHelper rest (x :: acc)
