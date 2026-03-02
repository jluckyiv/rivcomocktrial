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
        , ranksNotCombinedSuite
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
                Awards.scoreByRankPoints
                    [ ( alice, BestClerk, [ rank 1 ] ) ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 1 ]
        , test "multiple students sorted descending" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( bob, BestClerk, [ rank 2 ] )
                    , ( alice, BestBailiff, [ rank 1 ] )
                    ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 2, 1 ]
        , test "multiple rounds accumulate" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, BestClerk, [ rank 1, rank 2 ] )
                    , ( bob, BestBailiff, [ rank 2, rank 1 ] )
                    ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 3, 3 ]
        , test "equal totals preserved in order" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, BestClerk, [ rank 1 ] )
                    , ( bob, BestBailiff, [ rank 1 ] )
                    ]
                    |> List.map .student
                    |> Expect.equal [ alice, bob ]
        , test "empty rank list → 0 points" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, BestClerk, [] ) ]
                    |> List.map .totalRankPoints
                    |> Expect.equal [ 0 ]
        , test "StudentScore includes category" <|
            \_ ->
                Awards.scoreByRankPoints
                    [ ( alice, BestClerk, [ rank 1 ] ) ]
                    |> List.map .category
                    |> Expect.equal [ BestClerk ]
        ]


ranksNotCombinedSuite : Test
ranksNotCombinedSuite =
    let
        alice =
            TestHelpers.alice

        w1 =
            TestHelpers.witness1

        w2 =
            TestHelpers.witness2

        rank n =
            case Rank.fromInt n of
                Ok r ->
                    r

                Err _ ->
                    Debug.todo ("Invalid rank: " ++ String.fromInt n)

        expectSeparateScores description entry1 entry2 =
            test description <|
                \_ ->
                    Awards.scoreByRankPoints [ entry1, entry2 ]
                        |> List.length
                        |> Expect.equal 2
    in
    describe "ranks not combined across roles"
        [ -- Pretrial (BestAttorney) combinations
          expectSeparateScores
            "pretrial + trial attorney (different sides)"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestAttorney Defense, [ rank 2 ] )
        , expectSeparateScores
            "pretrial + witness (same side)"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestWitness w1, [ rank 2 ] )
        , expectSeparateScores
            "pretrial + witness (different sides)"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestWitness w2, [ rank 2 ] )
        , expectSeparateScores
            "pretrial + clerk"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestClerk, [ rank 2 ] )
        , expectSeparateScores
            "pretrial + bailiff"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestBailiff, [ rank 2 ] )

        -- Trial attorney combinations (not already covered)
        , expectSeparateScores
            "trial attorney on both sides"
            ( alice, BestAttorney Prosecution, [ rank 1 ] )
            ( alice, BestAttorney Defense, [ rank 2 ] )
        , expectSeparateScores
            "trial attorney + witness"
            ( alice, BestAttorney Defense, [ rank 1 ] )
            ( alice, BestWitness w1, [ rank 2 ] )
        , expectSeparateScores
            "trial attorney + clerk"
            ( alice, BestAttorney Defense, [ rank 1 ] )
            ( alice, BestClerk, [ rank 2 ] )
        , expectSeparateScores
            "trial attorney + bailiff"
            ( alice, BestAttorney Defense, [ rank 1 ] )
            ( alice, BestBailiff, [ rank 2 ] )

        -- Witness combinations (not already covered)
        , expectSeparateScores
            "witness on both sides"
            ( alice, BestWitness w1, [ rank 1 ] )
            ( alice, BestWitness w2, [ rank 2 ] )
        , expectSeparateScores
            "witness + clerk"
            ( alice, BestWitness w1, [ rank 1 ] )
            ( alice, BestClerk, [ rank 2 ] )
        , expectSeparateScores
            "witness + bailiff"
            ( alice, BestWitness w1, [ rank 1 ] )
            ( alice, BestBailiff, [ rank 2 ] )

        -- Clerk + bailiff
        , expectSeparateScores
            "clerk + bailiff"
            ( alice, BestClerk, [ rank 1 ] )
            ( alice, BestBailiff, [ rank 2 ] )
        ]
