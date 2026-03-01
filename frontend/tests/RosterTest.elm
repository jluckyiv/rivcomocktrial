module RosterTest exposing (suite)

import Expect
import Roster exposing (AttorneyDuty(..), RoleAssignment(..))
import Student exposing (Student)
import Test exposing (Test, describe, test)
import TestHelpers
import Witness


suite : Test
suite =
    let
        alice : Student
        alice =
            TestHelpers.alice

        witness =
            case Witness.create "Jordan Riley" "Lead Investigator" of
                Ok w ->
                    w

                Err _ ->
                    Debug.todo "Jordan Riley must be valid"
    in
    describe "Roster"
        [ describe "create"
            [ test "rejects empty list" <|
                \_ ->
                    Roster.create []
                        |> isErr
                        |> Expect.equal True
            , test "accepts non-empty list" <|
                \_ ->
                    Roster.create [ ClerkRole alice ]
                        |> isOk
                        |> Expect.equal True
            , test "assignments accessor round-trips" <|
                \_ ->
                    let
                        list =
                            [ ClerkRole alice, BailiffRole alice ]
                    in
                    Roster.create list
                        |> Result.map Roster.assignments
                        |> Expect.equal (Ok list)
            ]
        , describe "student"
            [ test "returns student from PretorialAttorney" <|
                \_ ->
                    PretorialAttorney alice
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from TrialAttorney" <|
                \_ ->
                    TrialAttorney alice Opening
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from WitnessRole" <|
                \_ ->
                    WitnessRole alice witness
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from ClerkRole" <|
                \_ ->
                    ClerkRole alice
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from BailiffRole" <|
                \_ ->
                    BailiffRole alice
                        |> Roster.student
                        |> Expect.equal alice
            ]
        , describe "AttorneyDuty"
            [ test "DirectOf carries a witness" <|
                \_ ->
                    DirectOf witness
                        |> (\duty ->
                                case duty of
                                    DirectOf w ->
                                        Witness.name w
                                            |> Expect.equal "Jordan Riley"

                                    _ ->
                                        Expect.fail "expected DirectOf"
                           )
            , test "CrossOf carries a witness" <|
                \_ ->
                    CrossOf witness
                        |> (\duty ->
                                case duty of
                                    CrossOf w ->
                                        Witness.name w
                                            |> Expect.equal "Jordan Riley"

                                    _ ->
                                        Expect.fail "expected CrossOf"
                           )
            ]
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
