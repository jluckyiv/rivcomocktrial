module TournamentTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Tournament exposing (Status(..))


suite : Test
suite =
    describe "Tournament"
        [ describe "statusToString"
            [ test "Draft → \"Draft\"" <|
                \_ ->
                    Tournament.statusToString Draft
                        |> Expect.equal "Draft"
            , test "Registration → \"Registration\"" <|
                \_ ->
                    Tournament.statusToString Registration
                        |> Expect.equal "Registration"
            , test "Active → \"Active\"" <|
                \_ ->
                    Tournament.statusToString Active
                        |> Expect.equal "Active"
            , test "Completed → \"Completed\"" <|
                \_ ->
                    Tournament.statusToString Completed
                        |> Expect.equal "Completed"
            ]
        ]
