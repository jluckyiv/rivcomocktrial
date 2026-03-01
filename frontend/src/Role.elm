module Role exposing (Role(..), side)

import Side exposing (Side(..))
import Witness exposing (Witness)


type Role
    = ProsecutionPretrial
    | ProsecutionAttorney
    | ProsecutionWitness Witness
    | DefensePretrial
    | DefenseAttorney
    | DefenseWitness Witness
    | Clerk
    | Bailiff


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
