module TeamTest exposing (suite)

import Coach
import District
import Expect
import School
import Student
import Team
import Test exposing (Test, describe, test)
import TestHelpers


suite : Test
suite =
    describe "Team"
        [ numberSuite
        , nameSuite
        , createSuite
        , mutatorSuite
        ]


numberSuite : Test
numberSuite =
    describe "numberFromInt"
        [ test "accepts 1" <|
            \_ ->
                Team.numberFromInt 1
                    |> isOk
                    |> Expect.equal True
        , test "accepts large number" <|
            \_ ->
                Team.numberFromInt 100
                    |> isOk
                    |> Expect.equal True
        , test "round-trips via numberToInt" <|
            \_ ->
                Team.numberFromInt 42
                    |> Result.map Team.numberToInt
                    |> Expect.equal (Ok 42)
        , test "rejects 0" <|
            \_ ->
                Team.numberFromInt 0
                    |> isErr
                    |> Expect.equal True
        , test "rejects negative" <|
            \_ ->
                Team.numberFromInt -1
                    |> isErr
                    |> Expect.equal True
        ]


nameSuite : Test
nameSuite =
    describe "nameFromString"
        [ test "accepts valid name" <|
            \_ ->
                Team.nameFromString "Eagles"
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty string" <|
            \_ ->
                Team.nameFromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only" <|
            \_ ->
                Team.nameFromString "   "
                    |> isErr
                    |> Expect.equal True
        , test "trims whitespace" <|
            \_ ->
                Team.nameFromString "  Eagles  "
                    |> Result.map Team.nameToString
                    |> Expect.equal (Ok "Eagles")
        , test "round-trips via nameToString" <|
            \_ ->
                Team.nameFromString "Eagles"
                    |> Result.map Team.nameToString
                    |> Expect.equal (Ok "Eagles")
        ]


createSuite : Test
createSuite =
    describe "create"
        [ test "creates team with empty students" <|
            \_ ->
                TestHelpers.teamA
                    |> Team.students
                    |> Expect.equal []
        , test "creates team with no attorney coach" <|
            \_ ->
                TestHelpers.teamA
                    |> Team.attorneyCoach
                    |> Expect.equal Nothing
        , test "teamNumber accessor works" <|
            \_ ->
                TestHelpers.teamA
                    |> Team.teamNumber
                    |> Team.numberToInt
                    |> Expect.equal 1
        , test "teamName accessor works" <|
            \_ ->
                TestHelpers.teamA
                    |> Team.teamName
                    |> Team.nameToString
                    |> Expect.equal "Team A"
        ]


mutatorSuite : Test
mutatorSuite =
    describe "mutators"
        [ test "addStudents appends students" <|
            \_ ->
                TestHelpers.teamA
                    |> Team.addStudents [ TestHelpers.alice ]
                    |> Team.students
                    |> List.length
                    |> Expect.equal 1
        , test "setAttorneyCoach sets coach" <|
            \_ ->
                let
                    ac =
                        Coach.createAttorneyCoach
                            (TestHelpers.coachName "Jane" "Doe")
                            Nothing
                in
                TestHelpers.teamA
                    |> Team.setAttorneyCoach ac
                    |> Team.attorneyCoach
                    |> Expect.notEqual Nothing
        ]


isOk : Result e a -> Bool
isOk result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


isErr : Result e a -> Bool
isErr result =
    not (isOk result)
