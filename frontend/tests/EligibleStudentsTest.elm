module EligibleStudentsTest exposing (suite)

import Coach
import District
import EligibleStudents exposing (Status(..))
import Email
import Error exposing (Error)
import Expect
import School
import Student
import Team
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "EligibleStudents"
        [ describe "defaultConfig"
            [ test "minStudents is 8 (Rule 2.2A)" <|
                \_ ->
                    EligibleStudents.defaultConfig.minStudents
                        |> Expect.equal 8
            , test "maxStudents is 25 (Rule 2.2A)" <|
                \_ ->
                    EligibleStudents.defaultConfig.maxStudents
                        |> Expect.equal 25
            ]
        , describe "create"
            [ test "returns Draft status" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.status
                        |> Expect.equal Draft
            , test "returns empty student list" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.students
                        |> List.length
                        |> Expect.equal 0
            , test "returns the team" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.team
                        |> Team.teamName
                        |> Team.nameToString
                        |> Expect.equal "Palm Desert"
            , test "stores config" <|
                \_ ->
                    let
                        cfg =
                            { minStudents = 5, maxStudents = 15 }
                    in
                    EligibleStudents.create cfg sampleTeam
                        |> EligibleStudents.config
                        |> Expect.equal cfg
            ]
        , describe "addStudent"
            [ test "in Draft succeeds" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.addStudent sampleStudent
                        |> Result.map EligibleStudents.students
                        |> Result.map List.length
                        |> Expect.equal (Ok 1)
            , test "rejects duplicates" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.addStudent sampleStudent
                        |> Result.andThen
                            (EligibleStudents.addStudent sampleStudent)
                        |> Expect.err
            , test "in Submitted fails" <|
                \_ ->
                    submittedEligibleStudents
                        |> EligibleStudents.addStudent sampleStudent
                        |> Expect.err
            , test "rejects when at maxStudents" <|
                \_ ->
                    let
                        cfg =
                            { minStudents = 2, maxStudents = 3 }

                        threeStudents =
                            [ makeStudent "A" "One" Student.HeHim
                            , makeStudent "B" "Two" Student.SheHer
                            , makeStudent "C" "Three" Student.TheyThem
                            ]

                        extraStudent =
                            makeStudent "D" "Four" Student.HeHim
                    in
                    EligibleStudents.create cfg sampleTeam
                        |> addAll threeStudents
                        |> Result.andThen
                            (EligibleStudents.addStudent extraStudent)
                        |> Expect.err
            ]
        , describe "removeStudent"
            [ test "in Draft removes student" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.addStudent sampleStudent
                        |> Result.map
                            (EligibleStudents.removeStudent sampleStudent)
                        |> Result.map EligibleStudents.students
                        |> Result.map List.length
                        |> Expect.equal (Ok 0)
            , test "in Submitted is no-op" <|
                \_ ->
                    let
                        firstStudent =
                            List.head
                                (EligibleStudents.students
                                    submittedEligibleStudents
                                )
                    in
                    case firstStudent of
                        Just s ->
                            submittedEligibleStudents
                                |> EligibleStudents.removeStudent s
                                |> EligibleStudents.students
                                |> List.length
                                |> Expect.equal 8

                        Nothing ->
                            Expect.fail "Expected at least one student"
            ]
        , describe "submit"
            [ test "with >= minStudents transitions to Submitted" <|
                \_ ->
                    submittedEligibleStudents
                        |> EligibleStudents.status
                        |> Expect.equal Submitted
            , test "with < minStudents fails" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.addStudent sampleStudent
                        |> Result.andThen EligibleStudents.submit
                        |> Expect.err
            , test "respects custom minStudents" <|
                \_ ->
                    let
                        cfg =
                            { minStudents = 3, maxStudents = 25 }

                        threeStudents =
                            [ makeStudent "A" "One" Student.HeHim
                            , makeStudent "B" "Two" Student.SheHer
                            , makeStudent "C" "Three" Student.TheyThem
                            ]
                    in
                    EligibleStudents.create cfg sampleTeam
                        |> addAll threeStudents
                        |> Result.andThen EligibleStudents.submit
                        |> Result.map EligibleStudents.status
                        |> Expect.equal (Ok Submitted)
            , test "when not Draft fails" <|
                \_ ->
                    submittedEligibleStudents
                        |> EligibleStudents.submit
                        |> Expect.err
            ]
        , describe "lock"
            [ test "from Submitted transitions to Locked" <|
                \_ ->
                    submittedEligibleStudents
                        |> EligibleStudents.lock
                        |> Result.map EligibleStudents.status
                        |> Expect.equal (Ok Locked)
            , test "from Draft fails" <|
                \_ ->
                    EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
                        |> EligibleStudents.lock
                        |> Expect.err
            ]
        , describe "statusToString"
            [ test "Draft" <|
                \_ ->
                    EligibleStudents.statusToString Draft
                        |> Expect.equal "Draft"
            , test "Submitted" <|
                \_ ->
                    EligibleStudents.statusToString Submitted
                        |> Expect.equal "Submitted"
            , test "Locked" <|
                \_ ->
                    EligibleStudents.statusToString Locked
                        |> Expect.equal "Locked"
            ]
        ]



-- HELPERS


sampleTeam : Team.Team
sampleTeam =
    let
        num =
            case Team.numberFromInt 1 of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid team number"

        name =
            case Team.nameFromString "Palm Desert" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid team name"

        distName =
            case District.nameFromString "Desert Sands USD" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid district name"

        sch =
            School.create
                (case School.nameFromString "Palm Desert High School" of
                    Ok n ->
                        n

                    Err _ ->
                        Debug.todo "Invalid school name"
                )
                (District.create distName)

        coachName =
            case Coach.nameFromStrings "Jane" "Doe" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Invalid coach name"

        coachEmail =
            case Email.fromString "jane@example.com" of
                Ok e ->
                    e

                Err _ ->
                    Debug.todo "Invalid email"

        tc =
            Coach.verify (Coach.apply coachName coachEmail)
    in
    Team.create num name sch tc


makeStudent : String -> String -> Student.Pronouns -> Student.Student
makeStudent first last pron =
    let
        name =
            case Student.nameFromStrings first last Nothing of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo ("Invalid student name: " ++ first ++ " " ++ last)
    in
    Student.create name pron


sampleStudent : Student.Student
sampleStudent =
    makeStudent "Jordan" "Smith" Student.TheyThem


eightStudents : List Student.Student
eightStudents =
    [ makeStudent "Alex" "Chen" Student.HeHim
    , makeStudent "Maria" "Garcia" Student.SheHer
    , makeStudent "Jordan" "Smith" Student.TheyThem
    , makeStudent "Sam" "Johnson" Student.HeHim
    , makeStudent "Riley" "Williams" Student.SheHer
    , makeStudent "Taylor" "Brown" Student.TheyThem
    , makeStudent "Morgan" "Davis" Student.HeHim
    , makeStudent "Casey" "Miller" Student.SheHer
    ]


addAll :
    List Student.Student
    -> EligibleStudents.EligibleStudents
    -> Result (List Error) EligibleStudents.EligibleStudents
addAll studs es =
    List.foldl
        (\s result ->
            Result.andThen (EligibleStudents.addStudent s) result
        )
        (Ok es)
        studs


submittedEligibleStudents : EligibleStudents.EligibleStudents
submittedEligibleStudents =
    case
        EligibleStudents.create EligibleStudents.defaultConfig sampleTeam
            |> addAll eightStudents
            |> Result.andThen EligibleStudents.submit
    of
        Ok es ->
            es

        Err _ ->
            Debug.todo "Failed to create submitted eligible students"
