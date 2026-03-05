module ConflictTest exposing (suite)

import Conflict
    exposing
        ( Conflict(..)
        , ConflictSubject(..)
        )
import Expect
import Round exposing (Round(..))
import School
import Team
import Test exposing (Test, describe, test)
import TestHelpers
import Volunteer


suite : Test
suite =
    describe "Conflict"
        [ describe "HardConflict"
            [ describe "creation"
                [ test "hardConflict creates with team subject" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamA)
                        in
                        hc
                            |> Conflict.hardConflictVolunteer
                            |> Volunteer.name
                            |> Volunteer.nameToString
                            |> Expect.equal "Test Scorer"
                , test "hardConflict preserves subject" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithSchool (Team.school TestHelpers.teamA))
                        in
                        hc
                            |> Conflict.hardConflictSubject
                            |> Expect.equal
                                (WithSchool (Team.school TestHelpers.teamA))
                ]
            , describe "checkHardConflicts"
                [ test "no conflicts returns empty" <|
                    \_ ->
                        Conflict.checkHardConflicts
                            []
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> Expect.equal []
                , test "WithTeam matches prosecution" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamA)
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "WithTeam matches defense" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamB)
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "WithTeam no match returns empty" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamC)
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> Expect.equal []
                , test "WithSchool matches prosecution school" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithSchool (Team.school TestHelpers.teamA))
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "WithSchool matches defense school" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithSchool (Team.school TestHelpers.teamB))
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "WithSchool no match returns empty" <|
                    \_ ->
                        let
                            hc =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithSchool (Team.school TestHelpers.teamC))
                        in
                        Conflict.checkHardConflicts
                            [ hc ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> Expect.equal []
                , test "multiple conflicts trigger independently" <|
                    \_ ->
                        let
                            hc1 =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamA)

                            hc2 =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamB)

                            hc3 =
                                Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamC)
                        in
                        Conflict.checkHardConflicts
                            [ hc1, hc2, hc3 ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 2
                ]
            ]
        , describe "SoftConflict"
            [ describe "checkSoftConflicts"
                [ test "no history returns empty" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            []
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> Expect.equal []
                , test "unrelated history returns empty" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamC
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> Expect.equal []
                , test "prosecution seen before triggers" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamA
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "defense seen before triggers" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamC
                              , TestHelpers.teamB
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "team seen as prosecution in history matches defense now" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamB
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 1
                , test "both teams seen in same round triggers two" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamA
                              , TestHelpers.teamB
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 2
                , test "team seen across multiple rounds triggers multiple" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamA
                              , TestHelpers.teamC
                              )
                            , ( Preliminary2
                              , TestHelpers.teamC
                              , TestHelpers.teamA
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.length
                            |> Expect.equal 2
                , test "records correct round" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary2
                              , TestHelpers.teamA
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.head
                            |> Maybe.map Conflict.softConflictRound
                            |> Expect.equal (Just Preliminary2)
                , test "records correct team" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamA
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.head
                            |> Maybe.map Conflict.softConflictTeam
                            |> Maybe.map Team.teamName
                            |> Maybe.map Team.nameToString
                            |> Expect.equal (Just "Team A")
                , test "records correct volunteer" <|
                    \_ ->
                        Conflict.checkSoftConflicts
                            TestHelpers.testScorer
                            [ ( Preliminary1
                              , TestHelpers.teamA
                              , TestHelpers.teamC
                              )
                            ]
                            TestHelpers.teamA
                            TestHelpers.teamB
                            |> List.head
                            |> Maybe.map Conflict.softConflictVolunteer
                            |> Maybe.map Volunteer.name
                            |> Maybe.map Volunteer.nameToString
                            |> Expect.equal (Just "Test Scorer")
                ]
            ]
        , describe "Conflict sum type"
            [ test "can combine Hard and Soft into unified list" <|
                \_ ->
                    let
                        hard =
                            Hard
                                (Conflict.hardConflict
                                    TestHelpers.testScorer
                                    (WithTeam TestHelpers.teamA)
                                )

                        soft =
                            Soft
                                (Conflict.softConflict
                                    TestHelpers.testScorer
                                    TestHelpers.teamA
                                    Preliminary1
                                )

                        conflicts =
                            [ hard, soft ]
                    in
                    conflicts
                        |> List.length
                        |> Expect.equal 2
            ]
        ]
