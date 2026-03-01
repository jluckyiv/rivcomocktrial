module RankTest exposing (suite)

import Expect
import Rank
    exposing
        ( NominationCategory(..)
        )
import Role exposing (Role(..), Witness(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Rank"
        [ rankSuite
        , nominationCategorySuite
        , rankPointsSuite
        ]


rankSuite : Test
rankSuite =
    describe "Rank smart constructor"
        [ test "fromInt 1 succeeds" <|
            \_ ->
                Rank.fromInt 1
                    |> isOk
                    |> Expect.equal True
        , test "fromInt 5 succeeds" <|
            \_ ->
                Rank.fromInt 5
                    |> isOk
                    |> Expect.equal True
        , test "fromInt 3 round-trips via toInt" <|
            \_ ->
                Rank.fromInt 3
                    |> Result.map Rank.toInt
                    |> Expect.equal (Ok 3)
        , test "fromInt 0 fails" <|
            \_ ->
                Rank.fromInt 0
                    |> isErr
                    |> Expect.equal True
        , test "fromInt 6 fails" <|
            \_ ->
                Rank.fromInt 6
                    |> isErr
                    |> Expect.equal True
        , test "fromInt -1 fails" <|
            \_ ->
                Rank.fromInt -1
                    |> isErr
                    |> Expect.equal True
        ]


nominationCategorySuite : Test
nominationCategorySuite =
    describe "nominationCategory"
        [ test "ProsecutionPretrial is Advocate" <|
            \_ ->
                Rank.nominationCategory ProsecutionPretrial
                    |> Expect.equal Advocate
        , test "ProsecutionAttorney is Advocate" <|
            \_ ->
                Rank.nominationCategory ProsecutionAttorney
                    |> Expect.equal Advocate
        , test "DefensePretrial is Advocate" <|
            \_ ->
                Rank.nominationCategory DefensePretrial
                    |> Expect.equal Advocate
        , test "DefenseAttorney is Advocate" <|
            \_ ->
                Rank.nominationCategory DefenseAttorney
                    |> Expect.equal Advocate
        , test "ProsecutionWitness is NonAdvocate" <|
            \_ ->
                Rank.nominationCategory
                    (ProsecutionWitness (Witness "Rio Sacks"))
                    |> Expect.equal NonAdvocate
        , test "DefenseWitness is NonAdvocate" <|
            \_ ->
                Rank.nominationCategory
                    (DefenseWitness (Witness "Haley Fromholz"))
                    |> Expect.equal NonAdvocate
        , test "Clerk is NonAdvocate" <|
            \_ ->
                Rank.nominationCategory Clerk
                    |> Expect.equal NonAdvocate
        , test "Bailiff is NonAdvocate" <|
            \_ ->
                Rank.nominationCategory Bailiff
                    |> Expect.equal NonAdvocate
        ]


rankPointsSuite : Test
rankPointsSuite =
    let
        rank n =
            case Rank.fromInt n of
                Ok r ->
                    r

                Err _ ->
                    Debug.todo ("Invalid rank: " ++ String.fromInt n)
    in
    describe "rankPoints"
        [ test "1st of 5 = 5 points" <|
            \_ ->
                Rank.rankPoints 5 (rank 1)
                    |> Expect.equal 5
        , test "5th of 5 = 1 point" <|
            \_ ->
                Rank.rankPoints 5 (rank 5)
                    |> Expect.equal 1
        , test "3rd of 5 = 3 points" <|
            \_ ->
                Rank.rankPoints 5 (rank 3)
                    |> Expect.equal 3
        , test "1st of 3 = 3 points" <|
            \_ ->
                Rank.rankPoints 3 (rank 1)
                    |> Expect.equal 3
        , test "3rd of 3 = 1 point" <|
            \_ ->
                Rank.rankPoints 3 (rank 3)
                    |> Expect.equal 1
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
