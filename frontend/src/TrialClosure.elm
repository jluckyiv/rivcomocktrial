module TrialClosure exposing
    ( completeTrial
    , verifyTrial
    )

import ActiveTrial exposing (ActiveTrial)
import BallotTracking exposing (BallotTracking, ScorerStatus(..))
import Error exposing (Error(..))


completeTrial :
    BallotTracking
    -> ActiveTrial
    -> Result (List Error) ActiveTrial
completeTrial tracking activeTrial =
    let
        ballotErrors =
            case BallotTracking.scorerStatus tracking of
                AwaitingSubmissions _ ->
                    [ Error "Cannot complete trial: not all ballots submitted" ]

                _ ->
                    []

        statusResult =
            ActiveTrial.completeTrial activeTrial
    in
    case ( ballotErrors, statusResult ) of
        ( [], Ok at ) ->
            Ok at

        ( [], Err errs ) ->
            Err errs

        ( bErrs, Ok _ ) ->
            Err bErrs

        ( bErrs, Err sErrs ) ->
            Err (bErrs ++ sErrs)


verifyTrial :
    BallotTracking
    -> ActiveTrial
    -> Result (List Error) ActiveTrial
verifyTrial tracking activeTrial =
    let
        ballotErrors =
            case BallotTracking.scorerStatus tracking of
                AllVerified ->
                    []

                _ ->
                    [ Error "Cannot verify trial: not all ballots verified" ]

        statusResult =
            ActiveTrial.verifyTrial activeTrial
    in
    case ( ballotErrors, statusResult ) of
        ( [], Ok at ) ->
            Ok at

        ( [], Err errs ) ->
            Err errs

        ( bErrs, Ok _ ) ->
            Err bErrs

        ( bErrs, Err sErrs ) ->
            Err (bErrs ++ sErrs)
