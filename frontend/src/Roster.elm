module Roster exposing
    ( AttorneyDuty(..)
    , RoleAssignment(..)
    , Roster
    , assignments
    , create
    , side
    , student
    )

import Error exposing (Error(..))
import Side exposing (Side(..))
import Student exposing (Student)
import Validate
import Witness exposing (Witness)


type AttorneyDuty
    = Opening
    | DirectOf Witness
    | CrossOf Witness
    | Closing


type RoleAssignment
    = PretrialAttorney Student
    | TrialAttorney Student AttorneyDuty
    | WitnessRole Student Witness
    | ClerkRole Student
    | BailiffRole Student
    | UnofficialTimer Student


type Roster
    = Roster Side (List RoleAssignment)


create : Side -> List RoleAssignment -> Result (List Error) Roster
create s list =
    Validate.validate
        (Validate.all
            [ Validate.ifEmptyList identity
                (Error "Roster cannot be empty")
            , exactlyOne countClerks "clerk"
            , exactlyOne countBailiffs "bailiff"
            , exactlyOne countPretrial "pretrial attorney"
            , validateWitnessCount
            , validateTrialAttorneyCount
            , validateNoDuplicateStudents
            , validateUnofficialTimer s
            ]
        )
        list
        |> Result.map (Validate.fromValid >> Roster s)


side : Roster -> Side
side (Roster s _) =
    s


assignments : Roster -> List RoleAssignment
assignments (Roster _ list) =
    list


student : RoleAssignment -> Student
student assignment =
    case assignment of
        PretrialAttorney s ->
            s

        TrialAttorney s _ ->
            s

        WitnessRole s _ ->
            s

        ClerkRole s ->
            s

        BailiffRole s ->
            s

        UnofficialTimer s ->
            s



-- Validators


exactlyOne :
    (List RoleAssignment -> Int)
    -> String
    -> Validate.Validator Error (List RoleAssignment)
exactlyOne counter label =
    Validate.fromErrors
        (\list ->
            let
                n =
                    counter list
            in
            if n == 1 then
                []

            else
                [ Error
                    ("Roster must have exactly 1 "
                        ++ label
                        ++ ", got "
                        ++ String.fromInt n
                    )
                ]
        )


validateWitnessCount : Validate.Validator Error (List RoleAssignment)
validateWitnessCount =
    Validate.fromErrors
        (\list ->
            let
                witnessCount =
                    countWitnesses list
            in
            if witnessCount == 4 then
                []

            else
                [ Error
                    ("Roster must have exactly 4 witnesses, got "
                        ++ String.fromInt witnessCount
                    )
                ]
        )


validateTrialAttorneyCount : Validate.Validator Error (List RoleAssignment)
validateTrialAttorneyCount =
    Validate.fromErrors
        (\list ->
            let
                n =
                    countTrialAttorneys list
            in
            if n >= 1 && n <= 3 then
                []

            else
                [ Error
                    ("Roster must have 1–3 trial attorneys, got "
                        ++ String.fromInt n
                    )
                ]
        )


validateNoDuplicateStudents : Validate.Validator Error (List RoleAssignment)
validateNoDuplicateStudents =
    Validate.fromErrors
        (\list ->
            let
                pretrialStudents =
                    List.filterMap
                        (\a ->
                            case a of
                                PretrialAttorney s ->
                                    Just s

                                _ ->
                                    Nothing
                        )
                        list

                witnessStudents =
                    List.filterMap
                        (\a ->
                            case a of
                                WitnessRole s _ ->
                                    Just s

                                _ ->
                                    Nothing
                        )
                        list

                -- Remove pretrial students from witness list
                -- (pretrial-as-witness is allowed)
                nonPretrialWitnesses =
                    List.filter
                        (\s -> not (List.member s pretrialStudents))
                        witnessStudents

                otherStudents =
                    List.filterMap
                        (\a ->
                            case a of
                                PretrialAttorney s ->
                                    Just s

                                TrialAttorney s _ ->
                                    Just s

                                ClerkRole s ->
                                    Just s

                                BailiffRole s ->
                                    Just s

                                UnofficialTimer s ->
                                    Just s

                                WitnessRole _ _ ->
                                    Nothing
                        )
                        list

                allStudents =
                    otherStudents ++ nonPretrialWitnesses
            in
            if hasDuplicates allStudents then
                [ Error "Roster has duplicate students" ]

            else
                []
        )


validateUnofficialTimer : Side -> Validate.Validator Error (List RoleAssignment)
validateUnofficialTimer s =
    Validate.fromErrors
        (\list ->
            let
                timerCount =
                    countTimers list
            in
            if timerCount == 0 then
                []

            else if s == Defense && timerCount == 1 then
                []

            else if s /= Defense then
                [ Error "Unofficial timer is only allowed on defense roster" ]

            else
                [ Error
                    ("Roster may have at most 1 unofficial timer, got "
                        ++ String.fromInt timerCount
                    )
                ]
        )



-- Counting helpers


countClerks : List RoleAssignment -> Int
countClerks =
    List.filter
        (\a ->
            case a of
                ClerkRole _ ->
                    True

                _ ->
                    False
        )
        >> List.length


countBailiffs : List RoleAssignment -> Int
countBailiffs =
    List.filter
        (\a ->
            case a of
                BailiffRole _ ->
                    True

                _ ->
                    False
        )
        >> List.length


countPretrial : List RoleAssignment -> Int
countPretrial =
    List.filter
        (\a ->
            case a of
                PretrialAttorney _ ->
                    True

                _ ->
                    False
        )
        >> List.length


countWitnesses : List RoleAssignment -> Int
countWitnesses =
    List.filter
        (\a ->
            case a of
                WitnessRole _ _ ->
                    True

                _ ->
                    False
        )
        >> List.length


countTrialAttorneys : List RoleAssignment -> Int
countTrialAttorneys =
    List.filter
        (\a ->
            case a of
                TrialAttorney _ _ ->
                    True

                _ ->
                    False
        )
        >> List.length


countTimers : List RoleAssignment -> Int
countTimers =
    List.filter
        (\a ->
            case a of
                UnofficialTimer _ ->
                    True

                _ ->
                    False
        )
        >> List.length


hasDuplicates : List a -> Bool
hasDuplicates list =
    case list of
        [] ->
            False

        x :: rest ->
            List.member x rest || hasDuplicates rest
