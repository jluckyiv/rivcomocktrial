module EmailTest exposing (suite)

import Email
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Email"
        [ test "accepts valid email" <|
            \_ ->
                Email.fromString "jane@example.com"
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty string" <|
            \_ ->
                Email.fromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only" <|
            \_ ->
                Email.fromString "   "
                    |> isErr
                    |> Expect.equal True
        , test "rejects missing @" <|
            \_ ->
                Email.fromString "notanemail"
                    |> isErr
                    |> Expect.equal True
        , test "trims whitespace and roundtrips" <|
            \_ ->
                Email.fromString "  jane@example.com  "
                    |> Result.map Email.toString
                    |> Expect.equal (Ok "jane@example.com")
        , test "roundtrips through toString" <|
            \_ ->
                Email.fromString "test@example.com"
                    |> Result.map Email.toString
                    |> Expect.equal (Ok "test@example.com")
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
