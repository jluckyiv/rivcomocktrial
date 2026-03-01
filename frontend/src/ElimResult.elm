module ElimResult exposing
    ( ElimVerdict(..)
    , ScorecardResult(..)
    , elimVerdict
    , elimVerdictWithPresider
    , scorecardResult
    )

import Error exposing (Error(..))
import PresiderBallot exposing (PresiderBallot)
import PrelimResult
import Side exposing (Side(..))
import Validate
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


elimVerdict :
    List VerifiedBallot
    -> Result (List Error) ElimVerdict
elimVerdict ballots =
    Validate.validate
        (Validate.ifEmptyList identity
            (Error "Cannot determine verdict from empty ballot list")
        )
        ballots
        |> Result.andThen
            (\valid ->
                let
                    validBallots =
                        Validate.fromValid valid
                in
                let
                    results =
                        List.map scorecardResult validBallots

                    pWins =
                        List.length (List.filter ((==) ProsecutionWon) results)

                    dWins =
                        List.length (List.filter ((==) DefenseWon) results)
                in
                if pWins > dWins then
                    Ok ProsecutionAdvances

                else if dWins > pWins then
                    Ok DefenseAdvances

                else
                    Ok ScorecardsTied
            )


elimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Result (List Error) Side
elimVerdictWithPresider presider ballots =
    elimVerdict ballots
        |> Result.map
            (\verdict ->
                case verdict of
                    ProsecutionAdvances ->
                        Prosecution

                    DefenseAdvances ->
                        Defense

                    ScorecardsTied ->
                        PresiderBallot.winner presider
            )
