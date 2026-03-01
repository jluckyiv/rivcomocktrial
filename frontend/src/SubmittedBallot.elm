module SubmittedBallot exposing
    ( Points
    , ScoredPresentation(..)
    , SubmittedBallot
    , Weight(..)
    , create
    , fromInt
    , points
    , presentations
    , side
    , student
    , toInt
    , weight
    , weightedPoints
    )

import Error exposing (Error(..))
import Side exposing (Side(..))
import Student exposing (Student)


type Points
    = Points Int


fromInt : Int -> Result (List Error) Points
fromInt n =
    if n >= 1 && n <= 10 then
        Ok (Points n)

    else
        Err [ Error ("Points must be 1–10, got " ++ String.fromInt n) ]


toInt : Points -> Int
toInt (Points n) =
    n


type ScoredPresentation
    = Pretrial Side Student Points
    | Opening Side Student Points
    | DirectExamination Side Student Points
    | CrossExamination Side Student Points
    | Closing Side Student Points
    | WitnessExamination Side Student Points
    | ClerkPerformance Student Points
    | BailiffPerformance Student Points


type SubmittedBallot
    = SubmittedBallot (List ScoredPresentation)


create : List ScoredPresentation -> Result (List Error) SubmittedBallot
create list =
    case list of
        [] ->
            Err [ Error "Ballot must have at least one presentation" ]

        _ ->
            Ok (SubmittedBallot list)


presentations : SubmittedBallot -> List ScoredPresentation
presentations (SubmittedBallot list) =
    list


type Weight
    = Single
    | Double


weight : ScoredPresentation -> Weight
weight presentation =
    case presentation of
        Pretrial _ _ _ ->
            Double

        Closing _ _ _ ->
            Double

        _ ->
            Single


points : ScoredPresentation -> Points
points presentation =
    case presentation of
        Pretrial _ _ p ->
            p

        Opening _ _ p ->
            p

        DirectExamination _ _ p ->
            p

        CrossExamination _ _ p ->
            p

        Closing _ _ p ->
            p

        WitnessExamination _ _ p ->
            p

        ClerkPerformance _ p ->
            p

        BailiffPerformance _ p ->
            p


student : ScoredPresentation -> Student
student presentation =
    case presentation of
        Pretrial _ s _ ->
            s

        Opening _ s _ ->
            s

        DirectExamination _ s _ ->
            s

        CrossExamination _ s _ ->
            s

        Closing _ s _ ->
            s

        WitnessExamination _ s _ ->
            s

        ClerkPerformance s _ ->
            s

        BailiffPerformance s _ ->
            s


side : ScoredPresentation -> Side
side presentation =
    case presentation of
        Pretrial s _ _ ->
            s

        Opening s _ _ ->
            s

        DirectExamination s _ _ ->
            s

        CrossExamination s _ _ ->
            s

        Closing s _ _ ->
            s

        WitnessExamination s _ _ ->
            s

        ClerkPerformance _ _ ->
            Prosecution

        BailiffPerformance _ _ ->
            Defense


weightedPoints : ScoredPresentation -> Int
weightedPoints presentation =
    let
        base =
            toInt (points presentation)
    in
    case weight presentation of
        Single ->
            base

        Double ->
            base * 2
