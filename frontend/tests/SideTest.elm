module SideTest exposing (..)

import Expect
import Side exposing (Side(..))
import Test exposing (Test, describe, test)


toStringTests : Test
toStringTests =
    describe "toString"
        [ test "Prosecution" <|
            \_ ->
                Prosecution
                    |> Side.toString
                    |> Expect.equal "Prosecution"
        , test "Defense" <|
            \_ ->
                Defense
                    |> Side.toString
                    |> Expect.equal "Defense"
        ]
