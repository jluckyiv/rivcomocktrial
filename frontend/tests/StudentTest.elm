module StudentTest exposing (suite)

import Expect
import Student exposing (Pronouns(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Student"
        [ nameSuite
        , pronounsSuite
        , studentSuite
        ]


nameSuite : Test
nameSuite =
    describe "Name"
        [ nameFromStringsSuite
        , displayNameTests
        , fullNameTests
        , accessorTests
        ]


nameFromStringsSuite : Test
nameFromStringsSuite =
    describe "nameFromStrings"
        [ test "succeeds with valid first and last" <|
            \_ ->
                Student.nameFromStrings "Robert" "Smith" Nothing
                    |> isOk
                    |> Expect.equal True
        , test "rejects empty first name" <|
            \_ ->
                Student.nameFromStrings "" "Smith" Nothing
                    |> isErr
                    |> Expect.equal True
        , test "rejects empty last name" <|
            \_ ->
                Student.nameFromStrings "Robert" "" Nothing
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only first name" <|
            \_ ->
                Student.nameFromStrings "   " "Smith" Nothing
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only last name" <|
            \_ ->
                Student.nameFromStrings "Robert" "   " Nothing
                    |> isErr
                    |> Expect.equal True
        , test "trims first and last" <|
            \_ ->
                Student.nameFromStrings "  Robert  " "  Smith  " Nothing
                    |> Result.map Student.fullName
                    |> Expect.equal (Ok "Robert Smith")
        , test "trims preferred name" <|
            \_ ->
                Student.nameFromStrings "Robert" "Smith" (Just "  Bob  ")
                    |> Result.map Student.preferred
                    |> Expect.equal (Ok (Just "Bob"))
        , test "blank preferred becomes Nothing" <|
            \_ ->
                Student.nameFromStrings "Robert" "Smith" (Just "   ")
                    |> Result.map Student.preferred
                    |> Expect.equal (Ok Nothing)
        ]


displayNameTests : Test
displayNameTests =
    describe "displayName"
        [ test "returns first name when no preferred name" <|
            \_ ->
                unsafeName "Robert" "Smith" Nothing
                    |> Student.displayName
                    |> Expect.equal "Robert"
        , test "returns preferred name when set" <|
            \_ ->
                unsafeName "Robert" "Smith" (Just "Bob")
                    |> Student.displayName
                    |> Expect.equal "Bob"
        ]


fullNameTests : Test
fullNameTests =
    describe "fullName"
        [ test "returns first and last when no preferred name" <|
            \_ ->
                unsafeName "Robert" "Smith" Nothing
                    |> Student.fullName
                    |> Expect.equal "Robert Smith"
        , test "returns preferred and last when preferred is set" <|
            \_ ->
                unsafeName "Robert" "Smith" (Just "Bob")
                    |> Student.fullName
                    |> Expect.equal "Bob Smith"
        ]


accessorTests : Test
accessorTests =
    describe "accessors"
        [ test "first returns first name" <|
            \_ ->
                unsafeName "Robert" "Smith" Nothing
                    |> Student.first
                    |> Expect.equal "Robert"
        , test "last returns last name" <|
            \_ ->
                unsafeName "Robert" "Smith" Nothing
                    |> Student.last
                    |> Expect.equal "Smith"
        , test "preferred returns Nothing when not set" <|
            \_ ->
                unsafeName "Robert" "Smith" Nothing
                    |> Student.preferred
                    |> Expect.equal Nothing
        , test "preferred returns Just when set" <|
            \_ ->
                unsafeName "Robert" "Smith" (Just "Bob")
                    |> Student.preferred
                    |> Expect.equal (Just "Bob")
        ]


pronounsSuite : Test
pronounsSuite =
    describe "Pronouns"
        [ toStringTests
        ]


toStringTests : Test
toStringTests =
    describe "pronounsToString"
        [ test "HeHim" <|
            \_ ->
                HeHim
                    |> Student.pronounsToString
                    |> Expect.equal "he/him"
        , test "SheHer" <|
            \_ ->
                SheHer
                    |> Student.pronounsToString
                    |> Expect.equal "she/her"
        , test "TheyThem" <|
            \_ ->
                TheyThem
                    |> Student.pronounsToString
                    |> Expect.equal "they/them"
        , test "Other with custom string" <|
            \_ ->
                Other "ze/zir"
                    |> Student.pronounsToString
                    |> Expect.equal "ze/zir"
        ]


studentSuite : Test
studentSuite =
    describe "create + studentName"
        [ test "studentName round-trips the name" <|
            \_ ->
                let
                    name =
                        unsafeName "Robert" "Smith" Nothing
                in
                Student.create name HeHim
                    |> Student.studentName
                    |> Student.fullName
                    |> Expect.equal "Robert Smith"
        , test "studentName reflects preferred name" <|
            \_ ->
                let
                    name =
                        unsafeName "Robert" "Smith" (Just "Bob")
                in
                Student.create name SheHer
                    |> Student.studentName
                    |> Student.displayName
                    |> Expect.equal "Bob"
        ]


unsafeName : String -> String -> Maybe String -> Student.Name
unsafeName f l p =
    case Student.nameFromStrings f l p of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid name: " ++ f ++ " " ++ l)


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
