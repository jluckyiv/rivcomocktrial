module Roster exposing
    ( AttorneyDuty(..)
    , RoleAssignment(..)
    , Roster
    , assignments
    , create
    , student
    )

import Error exposing (Error(..))
import Student exposing (Student)
import Validate
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


type Roster
    = Roster (List RoleAssignment)


create : List RoleAssignment -> Result (List Error) Roster
create list =
    Validate.validate
        (Validate.ifEmptyList identity
            (Error "Roster cannot be empty")
        )
        list
        |> Result.map (Validate.fromValid >> Roster)


assignments : Roster -> List RoleAssignment
assignments (Roster list) =
    list


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
