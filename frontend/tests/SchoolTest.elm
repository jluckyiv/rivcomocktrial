module SchoolTest exposing (suite)

import District
import Error exposing (Error(..))
import Expect
import School
import Test exposing (Test, describe, test)
import TestHelpers


suite : Test
suite =
    describe "School"
        [ nameFromStringSuite
        , createSuite
        ]


nameFromStringSuite : Test
nameFromStringSuite =
    describe "nameFromString"
        [ test "accepts a valid name" <|
            \_ ->
                School.nameFromString "Lincoln High"
                    |> isOk
                    |> Expect.equal True
        , test "round-trips through nameToString" <|
            \_ ->
                School.nameFromString "Lincoln High"
                    |> Result.map School.nameToString
                    |> Expect.equal (Ok "Lincoln High")
        , test "trims whitespace" <|
            \_ ->
                School.nameFromString "  Lincoln High  "
                    |> Result.map School.nameToString
                    |> Expect.equal (Ok "Lincoln High")
        , test "rejects blank string" <|
            \_ ->
                School.nameFromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only string" <|
            \_ ->
                School.nameFromString "   "
                    |> isErr
                    |> Expect.equal True
        ]


createSuite : Test
createSuite =
    describe "create"
        [ test "accessor round-trips school name" <|
            \_ ->
                let
                    sn =
                        TestHelpers.schoolName "Lincoln High"

                    dn =
                        TestHelpers.districtName "Riverside"

                    d =
                        District.create dn
                in
                School.create sn d
                    |> School.schoolName
                    |> School.nameToString
                    |> Expect.equal "Lincoln High"
        , test "accessor round-trips district" <|
            \_ ->
                let
                    sn =
                        TestHelpers.schoolName "Lincoln High"

                    dn =
                        TestHelpers.districtName "Riverside"

                    d =
                        District.create dn
                in
                School.create sn d
                    |> School.district
                    |> District.districtName
                    |> District.nameToString
                    |> Expect.equal "Riverside"
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
