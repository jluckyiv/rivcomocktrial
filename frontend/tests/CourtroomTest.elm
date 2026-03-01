module CourtroomTest exposing (suite)

import Courtroom
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Courtroom"
        [ describe "nameToString"
            [ test "round-trips through Name wrapper" <|
                \_ ->
                    Courtroom.name "Department 1"
                        |> Courtroom.nameToString
                        |> Expect.equal "Department 1"
            ]
        ]
