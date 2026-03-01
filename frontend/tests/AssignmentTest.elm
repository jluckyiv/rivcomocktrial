module AssignmentTest exposing (suite)

import Assignment exposing (Assignment(..))
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Assignment"
        [ describe "isAssigned"
            [ test "NotAssigned returns False" <|
                \_ ->
                    NotAssigned
                        |> Assignment.isAssigned
                        |> Expect.equal False
            , test "Assigned returns True" <|
                \_ ->
                    Assigned "hello"
                        |> Assignment.isAssigned
                        |> Expect.equal True
            ]
        , describe "toMaybe"
            [ test "NotAssigned returns Nothing" <|
                \_ ->
                    NotAssigned
                        |> Assignment.toMaybe
                        |> Expect.equal Nothing
            , test "Assigned returns Just" <|
                \_ ->
                    Assigned 42
                        |> Assignment.toMaybe
                        |> Expect.equal (Just 42)
            ]
        ]
