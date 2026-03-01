module ElimResult exposing
    ( ElimVerdict(..)
    , ScorecardResult(..)
    , elimVerdict
    , elimVerdictWithPresider
    , scorecardResult
    )

import PresiderBallot exposing (PresiderBallot)
import PrelimResult
import Side exposing (Side(..))
import VerifiedBallot exposing (VerifiedBallot)


type ScorecardResult
    = ProsecutionWon
    | DefenseWon
    | ScorecardTied


scorecardResult : VerifiedBallot -> ScorecardResult
scorecardResult ballot =
    let
        pTotal =
            PrelimResult.courtTotal Prosecution ballot

        dTotal =
            PrelimResult.courtTotal Defense ballot
    in
    if pTotal > dTotal then
        ProsecutionWon

    else if dTotal > pTotal then
        DefenseWon

    else
        ScorecardTied


type ElimVerdict
    = ProsecutionAdvances
    | DefenseAdvances
    | ScorecardsTied


elimVerdict : List VerifiedBallot -> ElimVerdict
elimVerdict ballots =
    let
        results =
            List.map scorecardResult ballots

        pWins =
            List.length (List.filter ((==) ProsecutionWon) results)

        dWins =
            List.length (List.filter ((==) DefenseWon) results)
    in
    if pWins > dWins then
        ProsecutionAdvances

    else if dWins > pWins then
        DefenseAdvances

    else
        ScorecardsTied


elimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Side
elimVerdictWithPresider presider ballots =
    case elimVerdict ballots of
        ProsecutionAdvances ->
            Prosecution

        DefenseAdvances ->
            Defense

        ScorecardsTied ->
            PresiderBallot.winner presider
