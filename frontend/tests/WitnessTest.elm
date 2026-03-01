module WitnessTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Witness


suite : Test
suite =
    describe "Witness"
        [ test "create succeeds with valid name and description" <|
            \_ ->
                Witness.create "Jordan Riley" "Lead Investigator"
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty name" <|
            \_ ->
                Witness.create "" "Lead Investigator"
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only name" <|
            \_ ->
                Witness.create "   " "Lead Investigator"
                    |> isErr
                    |> Expect.equal True
        , test "rejects empty description" <|
            \_ ->
                Witness.create "Jordan Riley" ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only description" <|
            \_ ->
                Witness.create "Jordan Riley" "   "
                    |> isErr
                    |> Expect.equal True
        , test "trims name" <|
            \_ ->
                Witness.create "  Jordan Riley  " "Lead Investigator"
                    |> Result.map Witness.name
                    |> Expect.equal (Ok "Jordan Riley")
        , test "trims description" <|
            \_ ->
                Witness.create "Jordan Riley" "  Lead Investigator  "
                    |> Result.map Witness.description
                    |> Expect.equal (Ok "Lead Investigator")
        , test "name accessor returns correct value" <|
            \_ ->
                Witness.create "Jordan Riley" "Lead Investigator"
                    |> Result.map Witness.name
                    |> Expect.equal (Ok "Jordan Riley")
        , test "description accessor returns correct value" <|
            \_ ->
                Witness.create "Jordan Riley" "Lead Investigator"
                    |> Result.map Witness.description
                    |> Expect.equal (Ok "Lead Investigator")
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
