module Role exposing (Role(..), Witness(..), side)

import Side exposing (Side(..))


type Role
    = ProsecutionPretrial
    | ProsecutionAttorney
    | ProsecutionWitness Witness
    | DefensePretrial
    | DefenseAttorney
    | DefenseWitness Witness
    | Clerk
    | Bailiff


type Witness
    = Witness String


side : Role -> Side
side role =
    case role of
        ProsecutionPretrial ->
            Prosecution

        ProsecutionAttorney ->
            Prosecution

        ProsecutionWitness _ ->
            Prosecution

        Clerk ->
            Prosecution

        DefensePretrial ->
            Defense

        DefenseAttorney ->
            Defense

        DefenseWitness _ ->
            Defense

        Bailiff ->
            Defense
