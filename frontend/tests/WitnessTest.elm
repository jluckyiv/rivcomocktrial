module WitnessTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Witness


suite : Test
suite =
    describe "Witness"
        [ test "toString returns the name given to fromString" <|
            \_ ->
                Witness.fromString "Jordan Riley"
                    |> Witness.toString
                    |> Expect.equal "Jordan Riley"
        ]
