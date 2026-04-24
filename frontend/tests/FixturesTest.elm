module FixturesTest exposing (suite)

import Expect
import Fixtures
import Set
import Team
import Test exposing (Test, describe, test)


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
        ]
