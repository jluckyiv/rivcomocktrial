module Rank exposing
    ( Nomination
    , NominationCategory(..)
    , Rank
    , fromInt
    , nominationCategory
    , rankPoints
    , toInt
    )

import Role exposing (Role(..))
import Student exposing (Student)


type Rank
    = Rank Int


fromInt : Int -> Maybe Rank
fromInt n =
    if n >= 1 && n <= 5 then
        Just (Rank n)

    else
        Nothing


toInt : Rank -> Int
toInt (Rank n) =
    n


type NominationCategory
    = Advocate
    | NonAdvocate


nominationCategory : Role -> NominationCategory
nominationCategory role =
    case role of
        ProsecutionPretrial ->
            Advocate

        ProsecutionAttorney ->
            Advocate

        DefensePretrial ->
            Advocate

        DefenseAttorney ->
            Advocate

        ProsecutionWitness _ ->
            NonAdvocate

        DefenseWitness _ ->
            NonAdvocate

        Clerk ->
            NonAdvocate

        Bailiff ->
            NonAdvocate


rankPoints : Int -> Rank -> Int
rankPoints count rank =
    count + 1 - toInt rank


type alias Nomination =
    { role : Role
    , student : Student
    , rank : Rank
    }
