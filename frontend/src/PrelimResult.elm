module PrelimResult exposing
    ( PrelimVerdict(..)
    , courtTotal
    , prelimVerdict
    , prelimVerdictWithPresider
    )

import PresiderBallot exposing (PresiderBallot)
import Side exposing (Side(..))
import SubmittedBallot
import VerifiedBallot exposing (VerifiedBallot)


type PrelimVerdict
    = ProsecutionWins
    | DefenseWins
    | CourtTotalTied


courtTotal : Side -> VerifiedBallot -> Int
courtTotal targetSide ballot =
    VerifiedBallot.presentations ballot
        |> List.filter (\p -> SubmittedBallot.side p == targetSide)
        |> List.map SubmittedBallot.weightedPoints
        |> List.sum


prelimVerdict : List VerifiedBallot -> PrelimVerdict
prelimVerdict ballots =
    let
        prosecutionTotal =
            List.map (courtTotal Prosecution) ballots |> List.sum

        defenseTotal =
            List.map (courtTotal Defense) ballots |> List.sum
    in
    if prosecutionTotal > defenseTotal then
        ProsecutionWins

    else if defenseTotal > prosecutionTotal then
        DefenseWins

    else
        CourtTotalTied


prelimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Side
prelimVerdictWithPresider presider ballots =
    case prelimVerdict ballots of
        ProsecutionWins ->
            Prosecution

        DefenseWins ->
            Defense

        CourtTotalTied ->
            PresiderBallot.winner presider
