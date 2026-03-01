module PrelimResult exposing
    ( PrelimVerdict(..)
    , courtTotal
    , prelimVerdict
    , prelimVerdictWithPresider
    )

import Error exposing (Error(..))
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


prelimVerdict :
    List VerifiedBallot
    -> Result (List Error) PrelimVerdict
prelimVerdict ballots =
    if List.isEmpty ballots then
        Err [ Error "Cannot determine verdict from empty ballot list" ]

    else
        let
            prosecutionTotal =
                List.map (courtTotal Prosecution) ballots |> List.sum

            defenseTotal =
                List.map (courtTotal Defense) ballots |> List.sum
        in
        if prosecutionTotal > defenseTotal then
            Ok ProsecutionWins

        else if defenseTotal > prosecutionTotal then
            Ok DefenseWins

        else
            Ok CourtTotalTied


prelimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Result (List Error) Side
prelimVerdictWithPresider presider ballots =
    prelimVerdict ballots
        |> Result.map
            (\verdict ->
                case verdict of
                    ProsecutionWins ->
                        Prosecution

                    DefenseWins ->
                        Defense

                    CourtTotalTied ->
                        PresiderBallot.winner presider
            )
