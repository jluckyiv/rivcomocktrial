module VolunteerTest exposing (suite)

import Email
import Expect
import Test exposing (Test, describe, test)
import TestHelpers
import TrialRole exposing (TrialRole(..))
import Volunteer


suite : Test
suite =
    describe "Volunteer"
        [ describe "nameFromStrings"
            [ test "valid name succeeds" <|
                \_ ->
                    Volunteer.nameFromStrings "Jane" "Doe"
                        |> Expect.ok
            , test "blank first name fails" <|
                \_ ->
                    Volunteer.nameFromStrings "" "Doe"
                        |> Expect.err
            , test "blank last name fails" <|
                \_ ->
                    Volunteer.nameFromStrings "Jane" ""
                        |> Expect.err
            , test "both blank fails with two errors" <|
                \_ ->
                    Volunteer.nameFromStrings "" ""
                        |> Result.mapError List.length
                        |> Expect.equal (Err 2)
            , test "trims whitespace" <|
                \_ ->
                    Volunteer.nameFromStrings "  Jane  " "  Doe  "
                        |> Result.map Volunteer.nameToString
                        |> Expect.equal (Ok "Jane Doe")
            , test "nameToString round-trips" <|
                \_ ->
                    Volunteer.nameFromStrings "Jane" "Doe"
                        |> Result.map Volunteer.nameToString
                        |> Expect.equal (Ok "Jane Doe")
            ]
        , describe "create"
            [ test "preserves name" <|
                \_ ->
                    let
                        volName =
                            TestHelpers.volunteerName "Jane" "Doe"

                        vol =
                            Volunteer.create volName
                                (TestHelpers.email "jane@example.com")
                                ScorerRole
                    in
                    vol
                        |> Volunteer.name
                        |> Volunteer.nameToString
                        |> Expect.equal "Jane Doe"
            , test "preserves email" <|
                \_ ->
                    let
                        e =
                            TestHelpers.email "jane@example.com"

                        vol =
                            Volunteer.create
                                (TestHelpers.volunteerName "Jane" "Doe")
                                e
                                ScorerRole
                    in
                    vol
                        |> Volunteer.email
                        |> Email.toString
                        |> Expect.equal "jane@example.com"
            , test "preserves role" <|
                \_ ->
                    let
                        vol =
                            Volunteer.create
                                (TestHelpers.volunteerName "Jane" "Doe")
                                (TestHelpers.email "jane@example.com")
                                PresiderRole
                    in
                    vol
                        |> Volunteer.role
                        |> Expect.equal PresiderRole
            ]
        , describe "TestHelpers fixtures"
            [ test "testScorer has expected name" <|
                \_ ->
                    TestHelpers.testScorer
                        |> Volunteer.name
                        |> Volunteer.nameToString
                        |> Expect.equal "Test Scorer"
            , test "testScorer has ScorerRole" <|
                \_ ->
                    TestHelpers.testScorer
                        |> Volunteer.role
                        |> Expect.equal ScorerRole
            , test "testPresider has expected name" <|
                \_ ->
                    TestHelpers.testPresider
                        |> Volunteer.name
                        |> Volunteer.nameToString
                        |> Expect.equal "Test Presider"
            , test "testPresider has PresiderRole" <|
                \_ ->
                    TestHelpers.testPresider
                        |> Volunteer.role
                        |> Expect.equal PresiderRole
            ]
        ]
