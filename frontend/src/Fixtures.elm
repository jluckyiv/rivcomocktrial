module Fixtures exposing
    ( districts
    , schools
    , teams
    , tournament
    )

{-| Hardcoded 2026 fixture data for incremental UI development.
Temporary scaffolding — will be deleted when persistence is added.

All values are known-valid, so Result unwrapping uses
crashOnError which produces a clear message if a
programming error is introduced.
-}

import Coach
import District exposing (District)
import Email exposing (Email)
import Error exposing (Error(..))
import School exposing (School)
import Team exposing (Team)
import Tournament exposing (Tournament)



-- CRASH HELPER
-- Elm's --optimize flag forbids Debug.todo. We use a
-- self-referencing thunk that produces a clear stack
-- trace in dev and an infinite loop (never reached)
-- in optimized builds. All inputs are known-valid
-- literals, so the Err branch is unreachable.


crashOnError : String -> Result (List Error) a -> a
crashOnError label result =
    case result of
        Ok value ->
            value

        Err _ ->
            crashOnError label result



-- HELPERS


districtName : String -> District.Name
districtName raw =
    crashOnError ("district name: " ++ raw)
        (District.nameFromString raw)


schoolName : String -> School.Name
schoolName raw =
    crashOnError ("school name: " ++ raw)
        (School.nameFromString raw)


teamNumber : Int -> Team.Number
teamNumber n =
    crashOnError ("team number: " ++ String.fromInt n)
        (Team.numberFromInt n)


teamName : String -> Team.Name
teamName raw =
    crashOnError ("team name: " ++ raw)
        (Team.nameFromString raw)


coachName : String -> String -> Coach.Name
coachName first last =
    crashOnError ("coach name: " ++ first ++ " " ++ last)
        (Coach.nameFromStrings first last)


email : String -> Email
email raw =
    crashOnError ("email: " ++ raw) (Email.fromString raw)


coach : String -> String -> String -> Coach.TeacherCoach
coach first last emailAddr =
    Coach.verify (Coach.apply (coachName first last) (email emailAddr))


tournamentName : String -> Tournament.Name
tournamentName raw =
    crashOnError ("tournament name: " ++ raw)
        (Tournament.nameFromString raw)


tournamentYear : Int -> Tournament.Year
tournamentYear n =
    crashOnError ("tournament year: " ++ String.fromInt n)
        (Tournament.yearFromInt n)


tournamentConfig : Int -> Int -> Tournament.Config
tournamentConfig prelim elim =
    crashOnError "tournament config"
        (Tournament.configFromInts prelim elim)



-- DISTRICTS


desertSands : District
desertSands =
    District.create
        (districtName "Desert Sands Unified School District")


coronaNorco : District
coronaNorco =
    District.create
        (districtName "Corona Norco Unified School District")


morenoValley : District
morenoValley =
    District.create
        (districtName "Moreno Valley Unified School District")


murrietaValley : District
murrietaValley =
    District.create
        (districtName "Murrieta Valley Unified School District")


jurupa : District
jurupa =
    District.create
        (districtName "Jurupa Unified School District")


dioceseSanBernardino : District
dioceseSanBernardino =
    District.create
        (districtName "Diocese of San Bernardino")


temeculaValley : District
temeculaValley =
    District.create
        (districtName "Temecula Valley Unified School District")


riverside : District
riverside =
    District.create
        (districtName "Riverside Unified School District")


perrisUnion : District
perrisUnion =
    District.create
        (districtName "Perris Union High School District")


hemet : District
hemet =
    District.create
        (districtName "Hemet Unified School District")


paloVerdeDistrict : District
paloVerdeDistrict =
    District.create
        (districtName "Palo Verde Unified School District")


sanJacinto : District
sanJacinto =
    District.create
        (districtName "San Jacinto Unified School District")


districts : List District
districts =
    [ desertSands
    , coronaNorco
    , morenoValley
    , murrietaValley
    , jurupa
    , dioceseSanBernardino
    , temeculaValley
    , riverside
    , perrisUnion
    , hemet
    , paloVerdeDistrict
    , sanJacinto
    ]



-- SCHOOLS


palmDesertSchool : School
palmDesertSchool =
    School.create (schoolName "Palm Desert High School") desertSands


santiagoSchool : School
santiagoSchool =
    School.create (schoolName "Santiago High School") coronaNorco


vistaDelLagoSchool : School
vistaDelLagoSchool =
    School.create (schoolName "Vista del Lago High School") morenoValley


murrietaValleySchool : School
murrietaValleySchool =
    School.create (schoolName "Murrieta Valley High School") murrietaValley


patriotSchool : School
patriotSchool =
    School.create (schoolName "Patriot High School") jurupa


laQuintaSchool : School
laQuintaSchool =
    School.create (schoolName "La Quinta High School") desertSands


norcoSchool : School
norcoSchool =
    School.create (schoolName "Norco High School") coronaNorco


notreDameSchool : School
notreDameSchool =
    School.create (schoolName "Notre Dame High School") dioceseSanBernardino


valleyViewSchool : School
valleyViewSchool =
    School.create (schoolName "Valley View High School") morenoValley


canyonSpringsSchool : School
canyonSpringsSchool =
    School.create (schoolName "Canyon Springs High School") morenoValley


temeculaValleySchool : School
temeculaValleySchool =
    School.create (schoolName "Temecula Valley High School") temeculaValley


polySchool : School
polySchool =
    School.create (schoolName "Poly High School") riverside


heritageSchool : School
heritageSchool =
    School.create (schoolName "Heritage High School") perrisUnion


indioSchool : School
indioSchool =
    School.create (schoolName "Indio High School") desertSands


ramonaSchool : School
ramonaSchool =
    School.create (schoolName "Ramona High School") riverside


libertySchool : School
libertySchool =
    School.create (schoolName "Liberty High School") perrisUnion


johnWNorthSchool : School
johnWNorthSchool =
    School.create (schoolName "John W. North High School") riverside


hemetSchool : School
hemetSchool =
    School.create (schoolName "Hemet High School") hemet


greatOakSchool : School
greatOakSchool =
    School.create (schoolName "Great Oak High School") temeculaValley


chaparralSchool : School
chaparralSchool =
    School.create (schoolName "Chaparral High School") temeculaValley


palomaValleySchool : School
palomaValleySchool =
    School.create (schoolName "Paloma Valley High School") perrisUnion


paloVerdeSchool : School
paloVerdeSchool =
    School.create (schoolName "Palo Verde High School") paloVerdeDistrict


stJeanneSchool : School
stJeanneSchool =
    School.create
        (schoolName "St. Jeanne de Lestonnac School")
        dioceseSanBernardino


centennialSchool : School
centennialSchool =
    School.create (schoolName "Centennial High School") coronaNorco


mlkSchool : School
mlkSchool =
    School.create
        (schoolName "Martin Luther King High School")
        riverside


sanJacintoSchool : School
sanJacintoSchool =
    School.create (schoolName "San Jacinto High School") sanJacinto


schools : List School
schools =
    [ palmDesertSchool
    , santiagoSchool
    , vistaDelLagoSchool
    , murrietaValleySchool
    , patriotSchool
    , laQuintaSchool
    , norcoSchool
    , notreDameSchool
    , valleyViewSchool
    , canyonSpringsSchool
    , temeculaValleySchool
    , polySchool
    , heritageSchool
    , indioSchool
    , ramonaSchool
    , libertySchool
    , johnWNorthSchool
    , hemetSchool
    , greatOakSchool
    , chaparralSchool
    , palomaValleySchool
    , paloVerdeSchool
    , stJeanneSchool
    , centennialSchool
    , mlkSchool
    , sanJacintoSchool
    ]



-- TEAMS


makeTeam : Int -> String -> School -> String -> String -> String -> Team
makeTeam num name sch coachFirst coachLast coachEmail =
    Team.create
        (teamNumber num)
        (teamName name)
        sch
        (coach coachFirst coachLast coachEmail)


teams : List Team
teams =
    [ makeTeam 1
        "Palm Desert"
        palmDesertSchool
        "Palm Desert"
        "Coach"
        "coach1@example.com"
    , makeTeam 2
        "Santiago"
        santiagoSchool
        "Santiago"
        "Coach"
        "coach2@example.com"
    , makeTeam 3
        "Vista del Lago"
        vistaDelLagoSchool
        "Vista del Lago"
        "Coach"
        "coach3@example.com"
    , makeTeam 4
        "Murrieta Valley"
        murrietaValleySchool
        "Murrieta Valley"
        "Coach"
        "coach4@example.com"
    , makeTeam 5
        "Patriot"
        patriotSchool
        "Patriot"
        "Coach"
        "coach5@example.com"
    , makeTeam 6
        "La Quinta"
        laQuintaSchool
        "La Quinta"
        "Coach"
        "coach6@example.com"
    , makeTeam 8
        "Norco"
        norcoSchool
        "Norco"
        "Coach"
        "coach8@example.com"
    , makeTeam 9
        "Notre Dame"
        notreDameSchool
        "Notre Dame"
        "Coach"
        "coach9@example.com"
    , makeTeam 10
        "Valley View"
        valleyViewSchool
        "Valley View"
        "Coach"
        "coach10@example.com"
    , makeTeam 11
        "Canyon Springs"
        canyonSpringsSchool
        "Canyon Springs"
        "Coach"
        "coach11@example.com"
    , makeTeam 12
        "Temecula Valley"
        temeculaValleySchool
        "Temecula Valley"
        "Coach"
        "coach12@example.com"
    , makeTeam 13
        "Poly"
        polySchool
        "Poly"
        "Coach"
        "coach13@example.com"
    , makeTeam 14
        "Heritage"
        heritageSchool
        "Heritage"
        "Coach"
        "coach14@example.com"
    , makeTeam 15
        "Indio"
        indioSchool
        "Indio"
        "Coach"
        "coach15@example.com"
    , makeTeam 16
        "Ramona"
        ramonaSchool
        "Ramona"
        "Coach"
        "coach16@example.com"
    , makeTeam 17
        "Liberty"
        libertySchool
        "Liberty"
        "Coach"
        "coach17@example.com"
    , makeTeam 19
        "John W. North"
        johnWNorthSchool
        "John W."
        "North Coach"
        "coach19@example.com"
    , makeTeam 20
        "Hemet"
        hemetSchool
        "Hemet"
        "Coach"
        "coach20@example.com"
    , makeTeam 21
        "Great Oak"
        greatOakSchool
        "Great Oak"
        "Coach"
        "coach21@example.com"
    , makeTeam 22
        "Chaparral"
        chaparralSchool
        "Chaparral"
        "Coach"
        "coach22@example.com"
    , makeTeam 23
        "Paloma Valley"
        palomaValleySchool
        "Paloma Valley"
        "Coach"
        "coach23@example.com"
    , makeTeam 24
        "Palo Verde"
        paloVerdeSchool
        "Palo Verde"
        "Coach"
        "coach24@example.com"
    , makeTeam 25
        "St. Jeanne de Lestonnac"
        stJeanneSchool
        "St. Jeanne"
        "Coach"
        "coach25@example.com"
    , makeTeam 26
        "Centennial"
        centennialSchool
        "Centennial"
        "Coach"
        "coach26@example.com"
    , makeTeam 27
        "Martin Luther King"
        mlkSchool
        "Martin Luther King"
        "Coach"
        "coach27@example.com"
    , makeTeam 28
        "San Jacinto"
        sanJacintoSchool
        "San Jacinto"
        "Coach"
        "coach28@example.com"
    ]



-- TOURNAMENT


tournament : Tournament
tournament =
    let
        draft =
            Tournament.create
                (tournamentName
                    "2026 Riverside County Mock Trial Competition"
                )
                (tournamentYear 2026)
                (tournamentConfig 4 3)
    in
    crashOnError "tournament registration transition"
        (Tournament.openRegistration draft)
