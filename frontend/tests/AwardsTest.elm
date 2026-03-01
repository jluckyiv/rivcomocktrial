module AwardsTest exposing (suite)

import Awards exposing (AwardCategory(..), StudentScore)
import Expect
import Rank exposing (NominationCategory(..))
import Side exposing (Side(..))
import Student
import Test exposing (Test, describe, test)
import TestHelpers
import Witness


suite : Test
suite =
    describe "Awards"
        [ nominationCategorySuite
        , scoreByRankPointsSuite
        ]


nominationCategorySuite : Test
nominationCategorySuite =
    describe "nominationCategory"
        [ test "BestAttorney Prosecution → Advocate" <|
            \_ ->
                Awards.nominationCategory (BestAttorney Prosecution)
                    |> Expect.equal Advocate
        , test "BestAttorney Defense → Advocate" <|
            \_ ->
                Awards.nominationCategory (BestAttorney Defense)
                    |> Expect.equal Advocate
        , test "BestWitness → NonAdvocate" <|
            \_ ->
                let
                    witness =
                        case Witness.create "Rio Sacks" "Detective" of
                            Ok w ->
                                w

                            Err _ ->
                                Debug.todo "Rio Sacks must be valid"
                in
                Awards.nominationCategory
                    (BestWitness witness)
                    |> Expect.equal NonAdvocate
        , test "BestClerk → NonAdvocate" <|
            \_ ->
                Awards.nominationCategory BestClerk
                    |> Expect.equal NonAdvocate
        , test "BestBailiff → NonAdvocate" <|
            \_ ->
                Awards.nominationCategory BestBailiff
                    |> Expect.equal NonAdvocate
        ]


scoreByRankPointsSuite : Test
scoreByRankPointsSuite =
    let
        alice =
            TestHelpers.alice

        bob =
            TestHelpers.bob

        rank n =
            case Rank.fromInt n of
                Ok r ->
                    r

                Err _ ->
                    Debug.todo ("Invalid rank: " ++ String.fromInt n)
    in
    describe "scoreByRankPoints"
        [ test "empty input → []" <|
            \_ ->
                Awards.scoreByRankPoints []
                    |> Expect.equal []
        , test "single student single rank" <|
            \_ ->
                -- count=1, rank=1 → rankPoints = 1+1-1 = 1
                Awards.scoreByRankPoints
                    [ ( alice, [ rank 1 ] ) ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 1 ]
        , test "multiple students sorted descending" <|
            \_ ->
                -- alice: count=2, rank 1 → 2+1-1=2
                -- bob:   count=2, rank 2 → 2+1-2=1
                Awards.scoreByRankPoints
                    [ ( bob, [ rank 2 ] )
                    , ( alice, [ rank 1 ] )
                    ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 2, 1 ]
        , test "multiple rounds accumulate" <|
            \_ ->
                -- alice: round1 count=2 rank1=2+1-1=2, round2 count=2 rank2=2+1-2=1 → 3
                -- bob:   round1 count=2 rank2=2+1-2=1, round2 count=2 rank1=2+1-1=2 → 3
                Awards.scoreByRankPoints
                    [ ( alice, [ rank 1, rank 2 ] )
                    , ( bob, [ rank 2, rank 1 ] )
                    ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 3, 3 ]
        , test "equal totals preserved in order" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, [ rank 1 ] )
                    , ( bob, [ rank 1 ] )
                    ]
                    |> List.map .student
                    |> Expect.equal [ alice, bob ]
        , test "empty rank list → 0 points" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, [] ) ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 0 ]
        ]
