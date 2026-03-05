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

import District
import PowerMatch exposing (RankedTeam)
import School
import Team exposing (Team)
import TestHelpers
    exposing
        ( coach
        , districtName
        , schoolName
        , teamName
        , teamNumber
        , trialFor
        )
import Trial exposing (Trial)



-- TEAM HELPERS


makeTeam : Int -> String -> Team
makeTeam num name =
    Team.create
        (teamNumber num)
        (teamName name)
        (School.create
            (schoolName ("School " ++ String.fromInt num))
            (District.create (districtName ("District " ++ String.fromInt num)))
        )
        (coach ("Coach" ++ String.fromInt num) "Test")


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


makeTrial : Team -> Team -> Trial
makeTrial =
    trialFor



-- ROUND 1 TRIALS


round1Trials : List Trial
round1Trials =
    [ makeTrial team06 team15
    , makeTrial team24 team01
    , makeTrial team19 team09
    , makeTrial team08 team11
    , makeTrial team05 team27
    , makeTrial team26 team13
    , makeTrial team10 team02
    , makeTrial team03 team16
    , makeTrial team04 team14
    , makeTrial team28 team25
    , makeTrial team22 team17
    , makeTrial team21 team12
    , makeTrial team23 team20
    ]



-- ROUND 2 TRIALS


round2Trials : List Trial
round2Trials =
    [ makeTrial team09 team23
    , makeTrial team02 team19
    , makeTrial team27 team21
    , makeTrial team16 team22
    , makeTrial team13 team04
    , makeTrial team12 team06
    , makeTrial team25 team03
    , makeTrial team15 team05
    , makeTrial team11 team24
    , makeTrial team20 team26
    , makeTrial team14 team28
    , makeTrial team17 team10
    , makeTrial team01 team08
    ]



-- ROUND 3 TRIALS


round3Trials : List Trial
round3Trials =
    [ makeTrial team25 team01
    , makeTrial team28 team05
    , makeTrial team23 team17
    , makeTrial team20 team12
    , makeTrial team06 team03
    , makeTrial team04 team02
    , makeTrial team26 team14
    , makeTrial team10 team08
    , makeTrial team19 team16
    , makeTrial team22 team09
    , makeTrial team21 team24
    , makeTrial team15 team11
    , makeTrial team27 team13
    ]



-- ROUND 4 TRIALS


round4Trials : List Trial
round4Trials =
    [ makeTrial team02 team15
    , makeTrial team16 team25
    , makeTrial team13 team21
    , makeTrial team24 team26
    , makeTrial team12 team22
    , makeTrial team11 team28
    , makeTrial team05 team10
    , makeTrial team01 team27
    , makeTrial team03 team23
    , makeTrial team08 team04
    , makeTrial team14 team06
    , makeTrial team17 team19
    , makeTrial team09 team20
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
