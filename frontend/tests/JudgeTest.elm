module JudgeTest exposing (suite)

import Email
import Error exposing (Error(..))
import Expect
import Judge
import Test exposing (Test, describe, test)
import TestHelpers


suite : Test
suite =
    describe "Judge"
        [ describe "nameFromStrings"
            [ test "valid name succeeds" <|
                \_ ->
                    Judge.nameFromStrings "Jane" "Doe"
                        |> Expect.ok
            , test "blank first name fails" <|
                \_ ->
                    Judge.nameFromStrings "" "Doe"
                        |> Expect.err
            , test "blank last name fails" <|
                \_ ->
                    Judge.nameFromStrings "Jane" ""
                        |> Expect.err
            , test "both blank fails with two errors" <|
                \_ ->
                    Judge.nameFromStrings "" ""
                        |> Result.mapError List.length
                        |> Expect.equal (Err 2)
            , test "trims whitespace" <|
                \_ ->
                    Judge.nameFromStrings "  Jane  " "  Doe  "
                        |> Result.map Judge.nameToString
                        |> Expect.equal (Ok "Jane Doe")
            , test "nameToString round-trips" <|
                \_ ->
                    Judge.nameFromStrings "Jane" "Doe"
                        |> Result.map Judge.nameToString
                        |> Expect.equal (Ok "Jane Doe")
            ]
        , describe "create"
            [ test "preserves name" <|
                \_ ->
                    let
                        judgeName =
                            TestHelpers.judgeName "Jane" "Doe"

                        judge =
                            Judge.create judgeName
                                (TestHelpers.email "jane@example.com")
                    in
                    judge
                        |> Judge.name
                        |> Judge.nameToString
                        |> Expect.equal "Jane Doe"
            , test "preserves email" <|
                \_ ->
                    let
                        e =
                            TestHelpers.email "jane@example.com"

                        judge =
                            Judge.create
                                (TestHelpers.judgeName "Jane" "Doe")
                                e
                    in
                    judge
                        |> Judge.email
                        |> Email.toString
                        |> Expect.equal "jane@example.com"
            ]
        , describe "TestHelpers.testJudge"
            [ test "has expected name" <|
                \_ ->
                    TestHelpers.testJudge
                        |> Judge.name
                        |> Judge.nameToString
                        |> Expect.equal "Test Judge"
            , test "has expected email" <|
                \_ ->
                    TestHelpers.testJudge
                        |> Judge.email
                        |> Email.toString
                        |> Expect.equal "judge@example.com"
            ]
        ]
