module PowerMatchFixtures exposing
    ( allTeams
    , makeRankedTeam
    , makeTeam
    , makeTrial
    , round1Trials
    , round2Trials
    , round3Trials
    , round4Trials
    , team01
    , team02
    , team03
    , team04
    , team05
    , team06
    , team08
    , team09
    , team10
    , team11
    , team12
    , team13
    , team14
    , team15
    , team16
    , team17
    , team19
    , team20
    , team21
    , team22
    , team23
    , team24
    , team25
    , team26
    , team27
    , team28
    , trialsThrough
    )

import Api exposing (Team, Trial)
import PowerMatch exposing (RankedTeam)



-- TEAM HELPERS


makeTeam : Int -> String -> Team
makeTeam num name =
    { id = "team_" ++ String.padLeft 2 '0' (String.fromInt num)
    , tournament = "tournament_2026"
    , school = "school_" ++ String.fromInt num
    , teamNumber = num
    , name = name
    , created = "2026-01-01"
    , updated = "2026-01-01"
    }


makeRankedTeam : Int -> String -> Int -> Int -> Int -> RankedTeam
makeRankedTeam num name wins losses rank =
    { team = makeTeam num name
    , wins = wins
    , losses = losses
    , rank = rank
    }



-- 26 TEAMS (2026 competition)


team01 : Team
team01 =
    makeTeam 1 "Palm Desert"


team02 : Team
team02 =
    makeTeam 2 "Santiago"


team03 : Team
team03 =
    makeTeam 3 "Vista del Lago"


team04 : Team
team04 =
    makeTeam 4 "Murrieta Valley"


team05 : Team
team05 =
    makeTeam 5 "Patriot"


team06 : Team
team06 =
    makeTeam 6 "La Quinta"


team08 : Team
team08 =
    makeTeam 8 "Norco"


team09 : Team
team09 =
    makeTeam 9 "Notre Dame"


team10 : Team
team10 =
    makeTeam 10 "Valley View"


team11 : Team
team11 =
    makeTeam 11 "Canyon Springs"


team12 : Team
team12 =
    makeTeam 12 "Temecula Valley"


team13 : Team
team13 =
    makeTeam 13 "Poly"


team14 : Team
team14 =
    makeTeam 14 "Heritage"


team15 : Team
team15 =
    makeTeam 15 "Indio"


team16 : Team
team16 =
    makeTeam 16 "Ramona"


team17 : Team
team17 =
    makeTeam 17 "Liberty"


team19 : Team
team19 =
    makeTeam 19 "John W. North"


team20 : Team
team20 =
    makeTeam 20 "Hemet"


team21 : Team
team21 =
    makeTeam 21 "Great Oak"


team22 : Team
team22 =
    makeTeam 22 "Chaparral"


team23 : Team
team23 =
    makeTeam 23 "Paloma Valley"


team24 : Team
team24 =
    makeTeam 24 "Palo Verde"


team25 : Team
team25 =
    makeTeam 25 "St. Jeanne de Lestonnac"


team26 : Team
team26 =
    makeTeam 26 "Centennial"


team27 : Team
team27 =
    makeTeam 27 "Martin Luther King"


team28 : Team
team28 =
    makeTeam 28 "San Jacinto"


allTeams : List Team
allTeams =
    [ team01
    , team02
    , team03
    , team04
    , team05
    , team06
    , team08
    , team09
    , team10
    , team11
    , team12
    , team13
    , team14
    , team15
    , team16
    , team17
    , team19
    , team20
    , team21
    , team22
    , team23
    , team24
    , team25
    , team26
    , team27
    , team28
    ]



-- TRIAL HELPERS


makeTrial : String -> Int -> String -> String -> Trial
makeTrial id roundNum prosecutionId defenseId =
    { id = id
    , round = "round_" ++ String.fromInt roundNum
    , prosecutionTeam = prosecutionId
    , defenseTeam = defenseId
    , courtroom = ""
    , created = "2026-01-01"
    , updated = "2026-01-01"
    }



-- ROUND 1 TRIALS


round1Trials : List Trial
round1Trials =
    [ makeTrial "r1_01" 1 team06.id team15.id
    , makeTrial "r1_02" 1 team24.id team01.id
    , makeTrial "r1_03" 1 team19.id team09.id
    , makeTrial "r1_04" 1 team08.id team11.id
    , makeTrial "r1_05" 1 team05.id team27.id
    , makeTrial "r1_06" 1 team26.id team13.id
    , makeTrial "r1_07" 1 team10.id team02.id
    , makeTrial "r1_08" 1 team03.id team16.id
    , makeTrial "r1_09" 1 team04.id team14.id
    , makeTrial "r1_10" 1 team28.id team25.id
    , makeTrial "r1_11" 1 team22.id team17.id
    , makeTrial "r1_12" 1 team21.id team12.id
    , makeTrial "r1_13" 1 team23.id team20.id
    ]



-- ROUND 2 TRIALS


round2Trials : List Trial
round2Trials =
    [ makeTrial "r2_01" 2 team09.id team23.id
    , makeTrial "r2_02" 2 team02.id team19.id
    , makeTrial "r2_03" 2 team27.id team21.id
    , makeTrial "r2_04" 2 team16.id team22.id
    , makeTrial "r2_05" 2 team13.id team04.id
    , makeTrial "r2_06" 2 team12.id team06.id
    , makeTrial "r2_07" 2 team25.id team03.id
    , makeTrial "r2_08" 2 team15.id team05.id
    , makeTrial "r2_09" 2 team11.id team24.id
    , makeTrial "r2_10" 2 team20.id team26.id
    , makeTrial "r2_11" 2 team14.id team28.id
    , makeTrial "r2_12" 2 team17.id team10.id
    , makeTrial "r2_13" 2 team01.id team08.id
    ]



-- ROUND 3 TRIALS


round3Trials : List Trial
round3Trials =
    [ makeTrial "r3_01" 3 team25.id team01.id
    , makeTrial "r3_02" 3 team28.id team05.id
    , makeTrial "r3_03" 3 team23.id team17.id
    , makeTrial "r3_04" 3 team20.id team12.id
    , makeTrial "r3_05" 3 team06.id team03.id
    , makeTrial "r3_06" 3 team04.id team02.id
    , makeTrial "r3_07" 3 team26.id team14.id
    , makeTrial "r3_08" 3 team10.id team08.id
    , makeTrial "r3_09" 3 team19.id team16.id
    , makeTrial "r3_10" 3 team22.id team09.id
    , makeTrial "r3_11" 3 team21.id team24.id
    , makeTrial "r3_12" 3 team15.id team11.id
    , makeTrial "r3_13" 3 team27.id team13.id
    ]



-- ROUND 4 TRIALS


round4Trials : List Trial
round4Trials =
    [ makeTrial "r4_01" 4 team02.id team15.id
    , makeTrial "r4_02" 4 team16.id team25.id
    , makeTrial "r4_03" 4 team13.id team21.id
    , makeTrial "r4_04" 4 team24.id team26.id
    , makeTrial "r4_05" 4 team12.id team22.id
    , makeTrial "r4_06" 4 team11.id team28.id
    , makeTrial "r4_07" 4 team05.id team10.id
    , makeTrial "r4_08" 4 team01.id team27.id
    , makeTrial "r4_09" 4 team03.id team23.id
    , makeTrial "r4_10" 4 team08.id team04.id
    , makeTrial "r4_11" 4 team14.id team06.id
    , makeTrial "r4_12" 4 team17.id team19.id
    , makeTrial "r4_13" 4 team09.id team20.id
    ]



-- HELPERS


{-| Get all trials through a given round number.
-}
trialsThrough : Int -> List Trial
trialsThrough roundNum =
    let
        rounds =
            [ ( 1, round1Trials )
            , ( 2, round2Trials )
            , ( 3, round3Trials )
            , ( 4, round4Trials )
            ]
    in
    rounds
        |> List.filter (\( n, _ ) -> n <= roundNum)
        |> List.concatMap Tuple.second
