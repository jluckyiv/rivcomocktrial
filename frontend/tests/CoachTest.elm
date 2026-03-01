module CoachTest exposing (suite)

import Coach
import Email
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Coach"
        [ nameSuite
        , verifySuite
        ]


nameSuite : Test
nameSuite =
    describe "nameFromStrings"
        [ test "succeeds with valid first and last" <|
            \_ ->
                Coach.nameFromStrings "Jane" "Doe"
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty first name" <|
            \_ ->
                Coach.nameFromStrings "" "Doe"
                    |> isErr
                    |> Expect.equal True
        , test "rejects empty last name" <|
            \_ ->
                Coach.nameFromStrings "Jane" ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only first name" <|
            \_ ->
                Coach.nameFromStrings "   " "Doe"
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only last name" <|
            \_ ->
                Coach.nameFromStrings "Jane" "   "
                    |> isErr
                    |> Expect.equal True
        , test "round-trips through nameToString" <|
            \_ ->
                Coach.nameFromStrings "Jane" "Doe"
                    |> Result.map Coach.nameToString
                    |> Expect.equal (Ok "Jane Doe")
        , test "trims whitespace from names" <|
            \_ ->
                Coach.nameFromStrings "  Jane  " "  Doe  "
                    |> Result.map Coach.nameToString
                    |> Expect.equal (Ok "Jane Doe")
        ]


verifySuite : Test
verifySuite =
    let
        name =
            case Coach.nameFromStrings "Jane" "Doe" of
                Ok n ->
                    n

                Err _ ->
                    Debug.todo "Jane Doe must be valid"

        janeEmail =
            case Email.fromString "jane@example.com" of
                Ok e ->
                    e

                Err _ ->
                    Debug.todo "jane@example.com must be valid"
    in
    describe "verify"
        [ test "preserves the applicant's name" <|
            \_ ->
                let
                    applicant =
                        Coach.apply name janeEmail
                in
                applicant
                    |> Coach.verify
                    |> Coach.teacherCoachName
                    |> Expect.equal name
        , test "preserves the applicant's email" <|
            \_ ->
                let
                    applicant =
                        Coach.apply name janeEmail
                in
                applicant
                    |> Coach.verify
                    |> Coach.teacherCoachEmail
                    |> Expect.equal janeEmail
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
