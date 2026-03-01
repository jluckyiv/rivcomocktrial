module NameTest exposing (..)

import Expect
import Student exposing (Name)
import Test exposing (Test, describe, test)


displayNameTests : Test
displayNameTests =
    describe "displayName"
        [ test "returns first name when no preferred name" <|
            \_ ->
                { first = "Robert", last = "Smith", preferred = Nothing }
                    |> Student.displayName
                    |> Expect.equal "Robert"
        , test "returns preferred name when set" <|
            \_ ->
                { first = "Robert", last = "Smith", preferred = Just "Bob" }
                    |> Student.displayName
                    |> Expect.equal "Bob"
        ]


fullNameTests : Test
fullNameTests =
    describe "fullName"
        [ test "returns first and last when no preferred name" <|
            \_ ->
                { first = "Robert", last = "Smith", preferred = Nothing }
                    |> Student.fullName
                    |> Expect.equal "Robert Smith"
        , test "returns preferred and last when preferred is set" <|
            \_ ->
                { first = "Robert", last = "Smith", preferred = Just "Bob" }
                    |> Student.fullName
                    |> Expect.equal "Bob Smith"
        ]
