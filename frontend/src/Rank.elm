module Rank exposing
    ( Nomination
    , NominationCategory(..)
    , Rank
    , fromInt
    , nominationCategory
    , rankPoints
    , toInt
    )

import Error exposing (Error(..))
import Role exposing (Role(..))
import Student exposing (Student)


type Rank
    = Rank Int


fromInt : Int -> Result (List Error) Rank
fromInt n =
    if n >= 1 && n <= 5 then
        Ok (Rank n)

    else
        Err [ Error ("Rank must be 1–5, got " ++ String.fromInt n) ]


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


rankPoints : Int -> Rank -> Result (List Error) Int
rankPoints count rank =
    if count >= 1 then
        Ok (count + 1 - toInt rank)

    else
        Err [ Error ("Nominee count must be positive, got " ++ String.fromInt count) ]


type alias Nomination =
    { role : Role
    , student : Student
    , rank : Rank
    }
