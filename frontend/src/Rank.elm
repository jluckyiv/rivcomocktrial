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
import Validate


type Rank
    = Rank Int


fromInt : Int -> Result (List Error) Rank
fromInt n =
    Validate.validate
        (Validate.fromErrors
            (\v ->
                if v >= 1 && v <= 5 then
                    []

                else
                    [ Error ("Rank must be 1–5, got " ++ String.fromInt v) ]
            )
        )
        n
        |> Result.map (Validate.fromValid >> Rank)


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
    Validate.validate
        (Validate.fromErrors
            (\c ->
                if c >= 1 then
                    []

                else
                    [ Error ("Nominee count must be positive, got " ++ String.fromInt c) ]
            )
        )
        count
        |> Result.map (\valid -> Validate.fromValid valid + 1 - toInt rank)


type alias Nomination =
    { role : Role
    , student : Student
    , rank : Rank
    }
