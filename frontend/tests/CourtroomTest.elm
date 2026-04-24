module CourtroomTest exposing (suite)

import Courtroom
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Courtroom"
        [ nameFromStringSuite
        , createSuite
        ]


nameFromStringSuite : Test
nameFromStringSuite =
    describe "nameFromString"
        [ test "accepts a valid name" <|
            \_ ->
                Courtroom.nameFromString "Department 1"
                    |> isOk
                    |> Expect.equal True
        , test "round-trips through nameToString" <|
            \_ ->
                Courtroom.nameFromString "Department 1"
                    |> Result.map Courtroom.nameToString
                    |> Expect.equal (Ok "Department 1")
        , test "trims whitespace" <|
            \_ ->
                Courtroom.nameFromString "  Department 1  "
                    |> Result.map Courtroom.nameToString
                    |> Expect.equal (Ok "Department 1")
        , test "rejects blank string" <|
            \_ ->
                Courtroom.nameFromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only string" <|
            \_ ->
                Courtroom.nameFromString "   "
                    |> isErr
                    |> Expect.equal True
        ]


createSuite : Test
createSuite =
    describe "create"
        [ test "accessor round-trips name" <|
            \_ ->
                case Courtroom.nameFromString "Department 1" of
                    Ok n ->
                        Courtroom.create n
                            |> Courtroom.courtroomName
                            |> Courtroom.nameToString
                            |> Expect.equal "Department 1"

                    Err _ ->
                        Expect.fail "nameFromString should succeed"
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
