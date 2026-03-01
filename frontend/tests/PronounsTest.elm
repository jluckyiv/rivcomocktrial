module PronounsTest exposing (..)

import Expect
import Student exposing (Pronouns(..))
import Test exposing (Test, describe, test)


toStringTests : Test
toStringTests =
    describe "pronounsToString"
        [ test "HeHim" <|
            \_ ->
                HeHim
                    |> Student.pronounsToString
                    |> Expect.equal "he/him"
        , test "SheHer" <|
            \_ ->
                SheHer
                    |> Student.pronounsToString
                    |> Expect.equal "she/her"
        , test "TheyThem" <|
            \_ ->
                TheyThem
                    |> Student.pronounsToString
                    |> Expect.equal "they/them"
        , test "Other with custom string" <|
            \_ ->
                Other "ze/zir"
                    |> Student.pronounsToString
                    |> Expect.equal "ze/zir"
        ]
