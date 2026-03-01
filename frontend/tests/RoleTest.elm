module RoleTest exposing (..)

import Expect
import Role exposing (Role(..))
import Side exposing (Side(..))
import Test exposing (Test, describe, test)
import Witness exposing (Witness)


witness : String -> String -> Witness
witness n d =
    case Witness.create n d of
        Ok w ->
            w

        Err _ ->
            Debug.todo ("Invalid witness: " ++ n)


sideTests : Test
sideTests =
    describe "side"
        [ test "ProsecutionPretrial is Prosecution" <|
            \_ ->
                ProsecutionPretrial
                    |> Role.side
                    |> Expect.equal Prosecution
        , test "ProsecutionAttorney is Prosecution" <|
            \_ ->
                ProsecutionAttorney
                    |> Role.side
                    |> Expect.equal Prosecution
        , test "ProsecutionWitness is Prosecution" <|
            \_ ->
                ProsecutionWitness (witness "Rio Sacks" "Detective")
                    |> Role.side
                    |> Expect.equal Prosecution
        , test "Clerk is Prosecution" <|
            \_ ->
                Clerk
                    |> Role.side
                    |> Expect.equal Prosecution
        , test "DefensePretrial is Defense" <|
            \_ ->
                DefensePretrial
                    |> Role.side
                    |> Expect.equal Defense
        , test "DefenseAttorney is Defense" <|
            \_ ->
                DefenseAttorney
                    |> Role.side
                    |> Expect.equal Defense
        , test "DefenseWitness is Defense" <|
            \_ ->
                DefenseWitness (witness "Casey Marshall" "Defendant")
                    |> Role.side
                    |> Expect.equal Defense
        , test "Bailiff is Defense" <|
            \_ ->
                Bailiff
                    |> Role.side
                    |> Expect.equal Defense
        ]
