module Roster exposing
    ( AttorneyDuty(..)
    , RoleAssignment(..)
    , Roster
    , student
    )

import Student exposing (Student)
import Witness exposing (Witness)


type AttorneyDuty
    = Opening
    | DirectOf Witness
    | CrossOf Witness
    | Closing


type RoleAssignment
    = PretorialAttorney Student
    | TrialAttorney Student AttorneyDuty
    | WitnessRole Student Witness
    | ClerkRole Student
    | BailiffRole Student


type alias Roster =
    { assignments : List RoleAssignment }


student : RoleAssignment -> Student
student assignment =
    case assignment of
        PretorialAttorney s ->
            s

        TrialAttorney s _ ->
            s

        WitnessRole s _ ->
            s

        ClerkRole s ->
            s

        BailiffRole s ->
            s
