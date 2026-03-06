module FixturesTest exposing (suite)

import District
import EligibleStudents
import Expect
import Fixtures
import Registration
import School
import Set
import Team
import Test exposing (Test, describe, test)
import Tournament


suite : Test
suite =
    describe "Fixtures"
        [ describe "teams"
            [ test "has 26 teams" <|
                \_ ->
                    Fixtures.teams
                        |> List.length
                        |> Expect.equal 26
            , test "all team numbers are in the expected set" <|
                \_ ->
                    let
                        expected =
                            Set.fromList
                                [ 1, 2, 3, 4, 5, 6, 8, 9, 10, 11
                                , 12, 13, 14, 15, 16, 17, 19, 20
                                , 21, 22, 23, 24, 25, 26, 27, 28
                                ]

                        actual =
                            Fixtures.teams
                                |> List.map
                                    (Team.teamNumber >> Team.numberToInt)
                                |> Set.fromList
                    in
                    Expect.equal expected actual
            , test "team numbers 7 and 18 are not used" <|
                \_ ->
                    let
                        numbers =
                            Fixtures.teams
                                |> List.map
                                    (Team.teamNumber >> Team.numberToInt)
                    in
                    Expect.equal True
                        (not (List.member 7 numbers)
                            && not (List.member 18 numbers)
                        )
            ]
        , describe "schools"
            [ test "has 26 schools" <|
                \_ ->
                    Fixtures.schools
                        |> List.length
                        |> Expect.equal 26
            ]
        , describe "districts"
            [ test "has 12 districts" <|
                \_ ->
                    Fixtures.districts
                        |> List.length
                        |> Expect.equal 12
            ]
        , describe "tournament"
            [ test "name is 2026 Riverside County Mock Trial Competition" <|
                \_ ->
                    Fixtures.tournament
                        |> Tournament.tournamentName
                        |> Tournament.nameToString
                        |> Expect.equal
                            "2026 Riverside County Mock Trial Competition"
            , test "year is 2026" <|
                \_ ->
                    Fixtures.tournament
                        |> Tournament.year
                        |> Tournament.yearToInt
                        |> Expect.equal 2026
            , test "config has 4 prelim and 3 elim rounds" <|
                \_ ->
                    let
                        cfg =
                            Tournament.config Fixtures.tournament
                    in
                    Expect.equal ( 4, 3 )
                        ( Tournament.prelimRounds cfg
                        , Tournament.elimRounds cfg
                        )
            , test "status is Registration" <|
                \_ ->
                    Fixtures.tournament
                        |> Tournament.status
                        |> Tournament.statusToString
                        |> Expect.equal "Registration"
            ]
        , describe "registrations"
            [ test "has 3 registrations" <|
                \_ ->
                    Fixtures.registrations
                        |> List.length
                        |> Expect.equal 3
            , test "includes 2 Pending and 1 Approved" <|
                \_ ->
                    let
                        statuses =
                            Fixtures.registrations
                                |> List.map Registration.status
                    in
                    Expect.equal
                        [ Registration.Pending
                        , Registration.Pending
                        , Registration.Approved
                        ]
                        statuses
            ]
        , describe "students"
            [ test "palmDesertStudents has 10 students" <|
                \_ ->
                    Fixtures.palmDesertStudents
                        |> List.length
                        |> Expect.equal 10
            , test "santiagoStudents has 10 students" <|
                \_ ->
                    Fixtures.santiagoStudents
                        |> List.length
                        |> Expect.equal 10
            ]
        , describe "eligibleStudents"
            [ test "palmDesertEligibleStudents status is Submitted" <|
                \_ ->
                    Fixtures.palmDesertEligibleStudents
                        |> EligibleStudents.status
                        |> Expect.equal EligibleStudents.Submitted
            , test "santiagoEligibleStudents status is Submitted" <|
                \_ ->
                    Fixtures.santiagoEligibleStudents
                        |> EligibleStudents.status
                        |> Expect.equal EligibleStudents.Submitted
            ]
        ]
