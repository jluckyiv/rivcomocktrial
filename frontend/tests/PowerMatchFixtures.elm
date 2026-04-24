module PowerMatchFixtures exposing
    ( allTeams
    , historyThrough
    , makeRankedTeam
    , makeTeam
    , round1History
    , round2History
    , round3History
    , round4History
    , team01
    , team02
    , team03
    , team04
    , team06
    , team09
    , team15
    , team16
    , team19
    , team22
    , team23
    )

import District
import MatchHistory exposing (MatchHistory, MatchRecord)
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
        )



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



-- MATCH HISTORY HELPERS


makeRecord : Team -> Team -> MatchRecord
makeRecord prosecution defense =
    { prosecution = prosecution, defense = defense }



-- ROUND 1 HISTORY


round1Records : List MatchRecord
round1Records =
    [ makeRecord team06 team15
    , makeRecord team24 team01
    , makeRecord team19 team09
    , makeRecord team08 team11
    , makeRecord team05 team27
    , makeRecord team26 team13
    , makeRecord team10 team02
    , makeRecord team03 team16
    , makeRecord team04 team14
    , makeRecord team28 team25
    , makeRecord team22 team17
    , makeRecord team21 team12
    , makeRecord team23 team20
    ]


round1History : MatchHistory
round1History =
    MatchHistory.fromRecords round1Records



-- ROUND 2 HISTORY


round2Records : List MatchRecord
round2Records =
    [ makeRecord team09 team23
    , makeRecord team02 team19
    , makeRecord team27 team21
    , makeRecord team16 team22
    , makeRecord team13 team04
    , makeRecord team12 team06
    , makeRecord team25 team03
    , makeRecord team15 team05
    , makeRecord team11 team24
    , makeRecord team20 team26
    , makeRecord team14 team28
    , makeRecord team17 team10
    , makeRecord team01 team08
    ]


round2History : MatchHistory
round2History =
    MatchHistory.fromRecords round2Records



-- ROUND 3 HISTORY


round3Records : List MatchRecord
round3Records =
    [ makeRecord team25 team01
    , makeRecord team28 team05
    , makeRecord team23 team17
    , makeRecord team20 team12
    , makeRecord team06 team03
    , makeRecord team04 team02
    , makeRecord team26 team14
    , makeRecord team10 team08
    , makeRecord team19 team16
    , makeRecord team22 team09
    , makeRecord team21 team24
    , makeRecord team15 team11
    , makeRecord team27 team13
    ]


round3History : MatchHistory
round3History =
    MatchHistory.fromRecords round3Records



-- ROUND 4 HISTORY


round4Records : List MatchRecord
round4Records =
    [ makeRecord team02 team15
    , makeRecord team16 team25
    , makeRecord team13 team21
    , makeRecord team24 team26
    , makeRecord team12 team22
    , makeRecord team11 team28
    , makeRecord team05 team10
    , makeRecord team01 team27
    , makeRecord team03 team23
    , makeRecord team08 team04
    , makeRecord team14 team06
    , makeRecord team17 team19
    , makeRecord team09 team20
    ]


round4History : MatchHistory
round4History =
    MatchHistory.fromRecords round4Records



-- HELPERS


{-| Get combined match history through a given round number.
-}
historyThrough : Int -> MatchHistory
historyThrough roundNum =
    let
        rounds =
            [ ( 1, round1Records )
            , ( 2, round2Records )
            , ( 3, round3Records )
            , ( 4, round4Records )
            ]
    in
    rounds
        |> List.filter (\( n, _ ) -> n <= roundNum)
        |> List.concatMap Tuple.second
        |> MatchHistory.fromRecords
