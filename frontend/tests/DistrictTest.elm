module DistrictTest exposing (suite)

import District
import Error exposing (Error(..))
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "District"
        [ nameFromStringSuite
        , createSuite
        ]


nameFromStringSuite : Test
nameFromStringSuite =
    describe "nameFromString"
        [ test "accepts a valid name" <|
            \_ ->
                District.nameFromString "Riverside"
                    |> isOk
                    |> Expect.equal True
        , test "round-trips through nameToString" <|
            \_ ->
                District.nameFromString "Riverside"
                    |> Result.map District.nameToString
                    |> Expect.equal (Ok "Riverside")
        , test "trims whitespace" <|
            \_ ->
                District.nameFromString "  Riverside  "
                    |> Result.map District.nameToString
                    |> Expect.equal (Ok "Riverside")
        , test "rejects blank string" <|
            \_ ->
                District.nameFromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only string" <|
            \_ ->
                District.nameFromString "   "
                    |> isErr
                    |> Expect.equal True
        ]


createSuite : Test
createSuite =
    describe "create"
        [ test "accessor round-trips name" <|
            \_ ->
                case District.nameFromString "Riverside" of
                    Ok n ->
                        District.create n
                            |> District.districtName
                            |> District.nameToString
                            |> Expect.equal "Riverside"

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
