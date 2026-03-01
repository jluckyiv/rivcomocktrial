module AwardsTest exposing (suite)

import Awards exposing (AwardCategory(..))
import Expect
import Rank exposing (NominationCategory(..))
import Side exposing (Side(..))
import Test exposing (Test, describe, test)
import Witness


suite : Test
suite =
    describe "Awards"
        [ describe "nominationCategory"
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
        ]
