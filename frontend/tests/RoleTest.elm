module RoleTest exposing (..)

import Expect
import Role exposing (Role(..), Witness(..))
import Side exposing (Side(..))
import Test exposing (Test, describe, test)


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
                ProsecutionWitness (Witness "Rio Sacks, Detective")
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
                DefenseWitness (Witness "Casey Marshall")
                    |> Role.side
                    |> Expect.equal Defense
        , test "Bailiff is Defense" <|
            \_ ->
                Bailiff
                    |> Role.side
                    |> Expect.equal Defense
        ]
