module ElimBracketTest exposing (..)

import ElimBracket exposing (Matchup, bracket, higherSeed, lowerSeed)
import ElimSideRules
import Error exposing (Error(..))
import Expect
import Side exposing (Side(..))
import Team exposing (Team)
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( coach
        , districtName
        , schoolName
        , teamName
        , teamNumber
        )

import District
import School


makeTeam : Int -> Team
makeTeam num =
    Team.create
        (teamNumber num)
        (teamName ("Team " ++ String.fromInt num))
        (School.create
            (schoolName ("School " ++ String.fromInt num))
            (District.create (districtName ("District " ++ String.fromInt num)))
        )
        (coach ("Coach" ++ String.fromInt num) "Test")


eightTeams : List Team
eightTeams =
    List.map makeTeam (List.range 1 8)


teamKey : Team -> Int
teamKey team =
    Team.numberToInt (Team.teamNumber team)


bracketTests : Test
bracketTests =
    describe "ElimBracket"
        [ describe "bracket"
            [ test "8 teams produces Ok with 4 matchups" <|
                \_ ->
                    case bracket eightTeams of
                        Ok matchups ->
                            List.length matchups |> Expect.equal 4

                        Err errs ->
                            Expect.fail ("Expected Ok, got Err: " ++ Debug.toString errs)
            , test "first matchup: seed 1 vs seed 8" <|
                \_ ->
                    case bracket eightTeams of
                        Ok (m :: _) ->
                            Expect.all
                                [ \_ -> teamKey (higherSeed m) |> Expect.equal 1
                                , \_ -> teamKey (lowerSeed m) |> Expect.equal 8
                                ]
                                ()

                        _ ->
                            Expect.fail "Expected at least one matchup"
            , test "second matchup: seed 2 vs seed 7" <|
                \_ ->
                    case bracket eightTeams of
                        Ok (_ :: m :: _) ->
                            Expect.all
                                [ \_ -> teamKey (higherSeed m) |> Expect.equal 2
                                , \_ -> teamKey (lowerSeed m) |> Expect.equal 7
                                ]
                                ()

                        _ ->
                            Expect.fail "Expected at least two matchups"
            , test "third matchup: seed 3 vs seed 6" <|
                \_ ->
                    case bracket eightTeams of
                        Ok (_ :: _ :: m :: _) ->
                            Expect.all
                                [ \_ -> teamKey (higherSeed m) |> Expect.equal 3
                                , \_ -> teamKey (lowerSeed m) |> Expect.equal 6
                                ]
                                ()

                        _ ->
                            Expect.fail "Expected at least three matchups"
            , test "fourth matchup: seed 4 vs seed 5" <|
                \_ ->
                    case bracket eightTeams of
                        Ok (_ :: _ :: _ :: m :: _) ->
                            Expect.all
                                [ \_ -> teamKey (higherSeed m) |> Expect.equal 4
                                , \_ -> teamKey (lowerSeed m) |> Expect.equal 5
                                ]
                                ()

                        _ ->
                            Expect.fail "Expected four matchups"
            , test "higherSeed accessor returns correct team" <|
                \_ ->
                    case bracket eightTeams of
                        Ok matchups ->
                            List.map (higherSeed >> teamKey) matchups
                                |> Expect.equal [ 1, 2, 3, 4 ]

                        Err _ ->
                            Expect.fail "Expected Ok"
            , test "lowerSeed accessor returns correct team" <|
                \_ ->
                    case bracket eightTeams of
                        Ok matchups ->
                            List.map (lowerSeed >> teamKey) matchups
                                |> Expect.equal [ 8, 7, 6, 5 ]

                        Err _ ->
                            Expect.fail "Expected Ok"
            , test "fewer than 8 teams returns Err" <|
                \_ ->
                    case bracket (List.map makeTeam (List.range 1 7)) of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Expected Err for 7 teams"
            , test "more than 8 teams returns Err" <|
                \_ ->
                    case bracket (List.map makeTeam (List.range 1 9)) of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Expected Err for 9 teams"
            , test "empty list returns Err" <|
                \_ ->
                    case bracket [] of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Expected Err for empty list"
            ]
        , describe "integration with ElimSideRules"
            [ test "bracket matchups feed into meetingHistory" <|
                \_ ->
                    case bracket eightTeams of
                        Ok (m :: _) ->
                            let
                                history =
                                    ElimSideRules.meetingHistory
                                        (higherSeed m)
                                        (lowerSeed m)
                                        []
                                        Prosecution
                            in
                            case history of
                                ElimSideRules.FirstMeeting _ ->
                                    Expect.pass

                                _ ->
                                    Expect.fail "Expected FirstMeeting for teams that never met"

                        _ ->
                            Expect.fail "Expected Ok with matchups"
            ]
        ]
