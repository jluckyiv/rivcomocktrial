module TrialsHelperTest exposing (suite)

import Expect
import Pages.Admin.Trials exposing (AssignmentField(..), applyFieldValue, fieldValue)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Pages.Admin.Trials helpers"
        [ fieldValueSuite
        , applyFieldValueSuite
        ]


fieldValueSuite : Test
fieldValueSuite =
    describe "fieldValue"
        [ test "JudgeField returns judge" <|
            \_ ->
                fieldValue JudgeField fakeTrial
                    |> Expect.equal "judge-id"
        , test "ScorerField 1 returns scorer1" <|
            \_ ->
                fieldValue (ScorerField 1) fakeTrial
                    |> Expect.equal "scorer-1-id"
        , test "ScorerField 2 returns scorer2" <|
            \_ ->
                fieldValue (ScorerField 2) fakeTrial
                    |> Expect.equal "scorer-2-id"
        , test "ScorerField 3 returns scorer3" <|
            \_ ->
                fieldValue (ScorerField 3) fakeTrial
                    |> Expect.equal "scorer-3-id"
        , test "ScorerField 4 returns scorer4" <|
            \_ ->
                fieldValue (ScorerField 4) fakeTrial
                    |> Expect.equal "scorer-4-id"
        , test "ScorerField 5 returns scorer5" <|
            \_ ->
                fieldValue (ScorerField 5) fakeTrial
                    |> Expect.equal "scorer-5-id"
        , test "ScorerField out of range falls through to scorer5" <|
            \_ ->
                fieldValue (ScorerField 99) fakeTrial
                    |> Expect.equal "scorer-5-id"
        ]


applyFieldValueSuite : Test
applyFieldValueSuite =
    describe "applyFieldValue"
        [ test "JudgeField updates judge" <|
            \_ ->
                applyFieldValue JudgeField "new-judge" fakeTrial
                    |> .judge
                    |> Expect.equal "new-judge"
        , test "JudgeField does not affect scorer slots" <|
            \_ ->
                applyFieldValue JudgeField "new-judge" fakeTrial
                    |> .scorer1
                    |> Expect.equal "scorer-1-id"
        , test "ScorerField 1 updates scorer1" <|
            \_ ->
                applyFieldValue (ScorerField 1) "new-scorer" fakeTrial
                    |> .scorer1
                    |> Expect.equal "new-scorer"
        , test "ScorerField 1 does not affect scorer2" <|
            \_ ->
                applyFieldValue (ScorerField 1) "new-scorer" fakeTrial
                    |> .scorer2
                    |> Expect.equal "scorer-2-id"
        , test "ScorerField 1 does not affect scorer5" <|
            \_ ->
                applyFieldValue (ScorerField 1) "new-scorer" fakeTrial
                    |> .scorer5
                    |> Expect.equal "scorer-5-id"
        , test "ScorerField 2 updates scorer2" <|
            \_ ->
                applyFieldValue (ScorerField 2) "new-scorer" fakeTrial
                    |> .scorer2
                    |> Expect.equal "new-scorer"
        , test "ScorerField 3 updates scorer3" <|
            \_ ->
                applyFieldValue (ScorerField 3) "new-scorer" fakeTrial
                    |> .scorer3
                    |> Expect.equal "new-scorer"
        , test "ScorerField 4 updates scorer4" <|
            \_ ->
                applyFieldValue (ScorerField 4) "new-scorer" fakeTrial
                    |> .scorer4
                    |> Expect.equal "new-scorer"
        , test "ScorerField 5 updates scorer5" <|
            \_ ->
                applyFieldValue (ScorerField 5) "new-scorer" fakeTrial
                    |> .scorer5
                    |> Expect.equal "new-scorer"
        , test "clearing a field sets it to empty string" <|
            \_ ->
                applyFieldValue JudgeField "" fakeTrial
                    |> .judge
                    |> Expect.equal ""
        ]



-- FIXTURES


fakeTrial : { id : String, round : String, prosecutionTeam : String, defenseTeam : String, courtroom : String, judge : String, scorer1 : String, scorer2 : String, scorer3 : String, scorer4 : String, scorer5 : String, created : String, updated : String }
fakeTrial =
    { id = "trial-1"
    , round = "round-1"
    , prosecutionTeam = "team-p"
    , defenseTeam = "team-d"
    , courtroom = "court-1"
    , judge = "judge-id"
    , scorer1 = "scorer-1-id"
    , scorer2 = "scorer-2-id"
    , scorer3 = "scorer-3-id"
    , scorer4 = "scorer-4-id"
    , scorer5 = "scorer-5-id"
    , created = "2026-01-01"
    , updated = "2026-01-01"
    }
