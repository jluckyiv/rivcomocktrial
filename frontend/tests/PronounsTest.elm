module PronounsTest exposing (..)

import Expect
import Pronouns exposing (Pronouns(..))
import Test exposing (Test, describe, test)


toStringTests : Test
toStringTests =
    describe "toString"
        [ test "HeHim" <|
            \_ ->
                HeHim
                    |> Pronouns.toString
                    |> Expect.equal "he/him"
        , test "SheHer" <|
            \_ ->
                SheHer
                    |> Pronouns.toString
                    |> Expect.equal "she/her"
        , test "TheyThem" <|
            \_ ->
                TheyThem
                    |> Pronouns.toString
                    |> Expect.equal "they/them"
        , test "Other with custom string" <|
            \_ ->
                Other "ze/zir"
                    |> Pronouns.toString
                    |> Expect.equal "ze/zir"
        ]
