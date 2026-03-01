module PowerMatch2026Test exposing (..)

import Api exposing (Trial)
import Expect
import PowerMatch exposing (hasPlayed, sideHistory)
import PowerMatchFixtures as F
import Test exposing (Test, describe, test)


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
                    allTrials =
                        F.trialsThrough 4

                    violations =
                        List.filter
                            (\team ->
                                let
                                    sides =
                                        sideHistory allTrials team.id
                                in
                                sides.prosecution /= 2
                            )
                            F.allTeams
                in
                violations
                    |> List.map .teamNumber
                    |> Expect.equal []
        , test "every team plays defense exactly 2 times" <|
            \_ ->
                let
                    allTrials =
                        F.trialsThrough 4

                    violations =
                        List.filter
                            (\team ->
                                let
                                    sides =
                                        sideHistory allTrials team.id
                                in
                                sides.defense /= 2
                            )
                            F.allTeams
                in
                violations
                    |> List.map .teamNumber
                    |> Expect.equal []
        ]



-- NO REMATCHES


noRematchTests : Test
noRematchTests =
    describe "2026 no rematches"
        [ test "R2 has no rematches from R1" <|
            \_ ->
                rematches F.round1Trials F.round2Trials
                    |> Expect.equal []
        , test "R3 has no rematches from R1-R2" <|
            \_ ->
                rematches (F.trialsThrough 2) F.round3Trials
                    |> Expect.equal []
        , test "R4 has no rematches from R1-R3" <|
            \_ ->
                rematches (F.trialsThrough 3) F.round4Trials
                    |> Expect.equal []
        , test "no team faces the same opponent twice across all 4 rounds" <|
            \_ ->
                let
                    allTrials =
                        F.trialsThrough 4

                    matchups =
                        List.map
                            (\t ->
                                normalizeMatchup t.prosecutionTeam
                                    t.defenseTeam
                            )
                            allTrials

                    duplicates =
                        findDuplicates matchups
                in
                duplicates |> Expect.equal []
        ]


{-| Return list of matchup descriptions that are rematches.
-}
rematches : List Trial -> List Trial -> List String
rematches priorTrials roundTrials =
    List.filterMap
        (\t ->
            if hasPlayed priorTrials t.prosecutionTeam t.defenseTeam then
                Just
                    (t.prosecutionTeam
                        ++ " vs "
                        ++ t.defenseTeam
                    )

            else
                Nothing
        )
        roundTrials



-- SIDE SWITCHING


sideSwitchingTests : Test
sideSwitchingTests =
    describe "2026 side switching"
        [ test "R1 prosecution teams play R2 defense" <|
            \_ ->
                let
                    r1ProsecutionIds =
                        List.map .prosecutionTeam F.round1Trials

                    -- These teams should appear as defense in R2
                    violations =
                        List.filter
                            (\t ->
                                List.member t.prosecutionTeam
                                    r1ProsecutionIds
                            )
                            F.round2Trials
                in
                violations
                    |> List.map .prosecutionTeam
                    |> Expect.equal []
        , test "R1 defense teams play R2 prosecution" <|
            \_ ->
                let
                    r1DefenseIds =
                        List.map .defenseTeam F.round1Trials

                    -- These teams should appear as prosecution in R2
                    violations =
                        List.filter
                            (\t ->
                                List.member t.defenseTeam
                                    r1DefenseIds
                            )
                            F.round2Trials
                in
                violations
                    |> List.map .defenseTeam
                    |> Expect.equal []
        , test "R3 prosecution teams play R4 defense" <|
            \_ ->
                let
                    r3ProsecutionIds =
                        List.map .prosecutionTeam F.round3Trials

                    violations =
                        List.filter
                            (\t ->
                                List.member t.prosecutionTeam
                                    r3ProsecutionIds
                            )
                            F.round4Trials
                in
                violations
                    |> List.map .prosecutionTeam
                    |> Expect.equal []
        , test "R3 defense teams play R4 prosecution" <|
            \_ ->
                let
                    r3DefenseIds =
                        List.map .defenseTeam F.round3Trials

                    violations =
                        List.filter
                            (\t ->
                                List.member t.defenseTeam
                                    r3DefenseIds
                            )
                            F.round4Trials
                in
                violations
                    |> List.map .defenseTeam
                    |> Expect.equal []
        ]



-- BRACKET PLACEMENT


bracketTests : Test
bracketTests =
    describe "2026 bracket placement"
        [ test "R3 pairings are all within-bracket (0 cross-bracket)" <|
            \_ ->
                -- After R2: 2-0, 1-1, 0-2
                -- R3 resets side switching, so all pairings can
                -- be within-bracket
                let
                    winsAfterR2 =
                        countWins (F.trialsThrough 2)

                    crossBracket =
                        List.filter
                            (\t ->
                                let
                                    pWins =
                                        getWins winsAfterR2
                                            t.prosecutionTeam

                                    dWins =
                                        getWins winsAfterR2
                                            t.defenseTeam
                                in
                                pWins /= dWins
                            )
                            F.round3Trials
                in
                List.length crossBracket
                    |> Expect.equal 0
        , test "R2 has 7 cross-bracket pairings" <|
            \_ ->
                let
                    winsAfterR1 =
                        countWins F.round1Trials

                    crossBracket =
                        List.filter
                            (\t ->
                                let
                                    pWins =
                                        getWins winsAfterR1
                                            t.prosecutionTeam

                                    dWins =
                                        getWins winsAfterR1
                                            t.defenseTeam
                                in
                                pWins /= dWins
                            )
                            F.round2Trials
                in
                List.length crossBracket
                    |> Expect.equal 7
        , test "R4 has 8 cross-bracket pairings" <|
            \_ ->
                let
                    winsAfterR3 =
                        countWins (F.trialsThrough 3)

                    crossBracket =
                        List.filter
                            (\t ->
                                let
                                    pWins =
                                        getWins winsAfterR3
                                            t.prosecutionTeam

                                    dWins =
                                        getWins winsAfterR3
                                            t.defenseTeam
                                in
                                pWins /= dWins
                            )
                            F.round4Trials
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
                [ List.length F.round1Trials
                , List.length F.round2Trials
                , List.length F.round3Trials
                , List.length F.round4Trials
                ]
                    |> Expect.equal [ 13, 13, 13, 13 ]
        , test "every team plays exactly 4 trials total" <|
            \_ ->
                let
                    allTrials =
                        F.trialsThrough 4

                    violations =
                        List.filter
                            (\team ->
                                let
                                    count =
                                        List.length
                                            (List.filter
                                                (\t ->
                                                    t.prosecutionTeam
                                                        == team.id
                                                        || t.defenseTeam
                                                        == team.id
                                                )
                                                allTrials
                                            )
                                in
                                count /= 4
                            )
                            F.allTeams
                in
                violations
                    |> List.map .teamNumber
                    |> Expect.equal []
        , test "26 unique teams across all trials" <|
            \_ ->
                let
                    allTrials =
                        F.trialsThrough 4

                    allIds =
                        List.concatMap
                            (\t ->
                                [ t.prosecutionTeam
                                , t.defenseTeam
                                ]
                            )
                            allTrials

                    unique =
                        removeDuplicates allIds
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
                        countWins F.round1Trials

                    oneWin =
                        List.filter
                            (\team -> getWins wins team.id == 1)
                            F.allTeams

                    zeroWins =
                        List.filter
                            (\team -> getWins wins team.id == 0)
                            F.allTeams
                in
                ( List.length oneWin, List.length zeroWins )
                    |> Expect.equal ( 13, 13 )
        , test "R1 winners are teams 1,2,4,8,9,12,13,15,16,20,22,25,27" <|
            \_ ->
                let
                    wins =
                        countWins F.round1Trials

                    winners =
                        F.allTeams
                            |> List.filter
                                (\t -> getWins wins t.id == 1)
                            |> List.map .teamNumber
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
                        countWins (F.trialsThrough 4)

                    byRecord =
                        List.map
                            (\w ->
                                List.length
                                    (List.filter
                                        (\t -> getWins wins t.id == w)
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
                        countWins (F.trialsThrough 4)

                    fourOh =
                        F.allTeams
                            |> List.filter
                                (\t -> getWins wins t.id == 4)
                            |> List.map .teamNumber
                            |> List.sort
                in
                fourOh |> Expect.equal [ 9, 13 ]
        ]



-- HELPERS


{-| Count wins for each team. A team wins if it appears
as prosecution and the prosecution score is higher, or
as defense and the defense score is higher. Since our
Trial type doesn't carry scores, we use the fixture data
winner convention: prosecution team wins odd-numbered
trials, defense wins even-numbered ones... actually we
can't determine winner from Trial alone.

Instead, we use the known winners from the fixture data.
We encode this by checking which team IDs appear as
winners in each round based on the known results.
-}
countWins : List Trial -> List ( String, Int )
countWins trials =
    let
        allTeamIds =
            List.concatMap
                (\t -> [ t.prosecutionTeam, t.defenseTeam ])
                trials
                |> removeDuplicates

        winCount teamId =
            List.length
                (List.filter
                    (\t -> isWinner t teamId)
                    trials
                )
    in
    List.map (\id -> ( id, winCount id )) allTeamIds


{-| Determine if a team won a trial based on the known
2026 results. We encode winners by mapping trial IDs
to the winning side.
-}
isWinner : Trial -> String -> Bool
isWinner trial teamId =
    case trialWinner trial of
        Just winnerId ->
            winnerId == teamId

        Nothing ->
            False


{-| Return the winner's team ID for a known trial.
Maps each fixture trial ID to the winning team based on
the 2026 official results.
-}
trialWinner : Trial -> Maybe String
trialWinner trial =
    -- R1 winners: D, D, D, P, D, D, D, D, P, D, P, D, D
    case trial.id of
        -- Round 1
        "r1_01" ->
            Just trial.defenseTeam

        -- La Quinta v Indio → D (Indio)
        "r1_02" ->
            Just trial.defenseTeam

        -- Palo Verde v Palm Desert → D
        "r1_03" ->
            Just trial.defenseTeam

        -- JW North v Notre Dame → D
        "r1_04" ->
            Just trial.prosecutionTeam

        -- Norco v Canyon Springs → P
        "r1_05" ->
            Just trial.defenseTeam

        -- Patriot v MLK → D
        "r1_06" ->
            Just trial.defenseTeam

        -- Centennial v Poly → D
        "r1_07" ->
            Just trial.defenseTeam

        -- Valley View v Santiago → D
        "r1_08" ->
            Just trial.defenseTeam

        -- Vista del Lago v Ramona → D
        "r1_09" ->
            Just trial.prosecutionTeam

        -- Murrieta Valley v Heritage → P
        "r1_10" ->
            Just trial.defenseTeam

        -- San Jacinto v St. Jeanne → D
        "r1_11" ->
            Just trial.prosecutionTeam

        -- Chaparral v Liberty → P
        "r1_12" ->
            Just trial.defenseTeam

        -- Great Oak v Temecula Valley → D
        "r1_13" ->
            Just trial.defenseTeam

        -- Paloma Valley v Hemet → D
        -- Round 2
        "r2_01" ->
            Just trial.prosecutionTeam

        -- Notre Dame v Paloma Valley → P
        "r2_02" ->
            Just trial.defenseTeam

        -- Santiago v JW North → D
        "r2_03" ->
            Just trial.prosecutionTeam

        -- MLK v Great Oak → P
        "r2_04" ->
            Just trial.defenseTeam

        -- Ramona v Chaparral → D
        "r2_05" ->
            Just trial.prosecutionTeam

        -- Poly v Murrieta Valley → P
        "r2_06" ->
            Just trial.prosecutionTeam

        -- Temecula Valley v La Quinta → P
        "r2_07" ->
            Just trial.prosecutionTeam

        -- St. Jeanne v Vista del Lago → P
        "r2_08" ->
            Just trial.defenseTeam

        -- Indio v Patriot → D
        "r2_09" ->
            Just trial.prosecutionTeam

        -- Canyon Springs v Palo Verde → P
        "r2_10" ->
            Just trial.prosecutionTeam

        -- Hemet v Centennial → P
        "r2_11" ->
            Just trial.defenseTeam

        -- Heritage v San Jacinto → D
        "r2_12" ->
            Just trial.defenseTeam

        -- Liberty v Valley View → D
        "r2_13" ->
            Just trial.prosecutionTeam

        -- Palm Desert v Norco → P
        -- Round 3
        "r3_01" ->
            Just trial.defenseTeam

        -- St. Jeanne v Palm Desert → D
        "r3_02" ->
            Just trial.defenseTeam

        -- San Jacinto v Patriot → D
        "r3_03" ->
            Just trial.prosecutionTeam

        -- Paloma Valley v Liberty → P
        "r3_04" ->
            Just trial.defenseTeam

        -- Hemet v Temecula Valley → D
        "r3_05" ->
            Just trial.prosecutionTeam

        -- La Quinta v Vista del Lago → P
        "r3_06" ->
            Just trial.defenseTeam

        -- Murrieta Valley v Santiago → D
        "r3_07" ->
            Just trial.prosecutionTeam

        -- Centennial v Heritage → P
        "r3_08" ->
            Just trial.prosecutionTeam

        -- Valley View v Norco → P
        "r3_09" ->
            Just trial.defenseTeam

        -- JW North v Ramona → D
        "r3_10" ->
            Just trial.defenseTeam

        -- Chaparral v Notre Dame → D
        "r3_11" ->
            Just trial.prosecutionTeam

        -- Great Oak v Palo Verde → P
        "r3_12" ->
            Just trial.prosecutionTeam

        -- Indio v Canyon Springs → P
        "r3_13" ->
            Just trial.defenseTeam

        -- MLK v Poly → D
        -- Round 4
        "r4_01" ->
            Just trial.prosecutionTeam

        -- Santiago v Indio → P
        "r4_02" ->
            Just trial.prosecutionTeam

        -- Ramona v St. Jeanne → P
        "r4_03" ->
            Just trial.prosecutionTeam

        -- Poly v Great Oak → P
        "r4_04" ->
            Just trial.defenseTeam

        -- Palo Verde v Centennial → D
        "r4_05" ->
            Just trial.defenseTeam

        -- Temecula Valley v Chaparral → D
        "r4_06" ->
            Just trial.prosecutionTeam

        -- Canyon Springs v San Jacinto → P
        "r4_07" ->
            Just trial.defenseTeam

        -- Patriot v Valley View → D
        "r4_08" ->
            Just trial.defenseTeam

        -- Palm Desert v MLK → D
        "r4_09" ->
            Just trial.defenseTeam

        -- Vista del Lago v Paloma Valley → D
        "r4_10" ->
            Just trial.defenseTeam

        -- Norco v Murrieta Valley → D
        "r4_11" ->
            Just trial.prosecutionTeam

        -- Heritage v La Quinta → P
        "r4_12" ->
            Just trial.defenseTeam

        -- Liberty v JW North → D
        "r4_13" ->
            Just trial.prosecutionTeam

        -- Notre Dame v Hemet → P
        _ ->
            Nothing


getWins : List ( String, Int ) -> String -> Int
getWins winList teamId =
    List.filter (\( id, _ ) -> id == teamId) winList
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault 0


normalizeMatchup : String -> String -> ( String, String )
normalizeMatchup a b =
    if a < b then
        ( a, b )

    else
        ( b, a )


findDuplicates : List ( String, String ) -> List ( String, String )
findDuplicates matchups =
    findDuplicatesHelper matchups [] []


findDuplicatesHelper :
    List ( String, String )
    -> List ( String, String )
    -> List ( String, String )
    -> List ( String, String )
findDuplicatesHelper remaining seen dupes =
    case remaining of
        [] ->
            dupes

        m :: rest ->
            if List.member m seen then
                findDuplicatesHelper rest seen (m :: dupes)

            else
                findDuplicatesHelper rest (m :: seen) dupes


removeDuplicates : List String -> List String
removeDuplicates items =
    removeDuplicatesHelper items []


removeDuplicatesHelper : List String -> List String -> List String
removeDuplicatesHelper remaining acc =
    case remaining of
        [] ->
            List.reverse acc

        x :: rest ->
            if List.member x acc then
                removeDuplicatesHelper rest acc

            else
                removeDuplicatesHelper rest (x :: acc)
