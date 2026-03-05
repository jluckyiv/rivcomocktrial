module ActiveTrial exposing
    ( ActiveTrial
    , TrialStatus(..)
    , completeTrial
    , fromTrial
    , startTrial
    , status
    , statusToString
    , trial
    , verifyTrial
    )

import Error exposing (Error(..))
import Trial exposing (Trial)


type TrialStatus
    = AwaitingCheckIn
    | InProgress
    | Complete
    | Verified


type ActiveTrial
    = ActiveTrial
        { trial : Trial
        , status : TrialStatus
        }


fromTrial : Trial -> ActiveTrial
fromTrial t =
    ActiveTrial { trial = t, status = AwaitingCheckIn }


trial : ActiveTrial -> Trial
trial (ActiveTrial r) =
    r.trial


status : ActiveTrial -> TrialStatus
status (ActiveTrial r) =
    r.status


startTrial : ActiveTrial -> Result (List Error) ActiveTrial
startTrial (ActiveTrial r) =
    case r.status of
        AwaitingCheckIn ->
            Ok (ActiveTrial { r | status = InProgress })

        other ->
            Err
                [ Error
                    ("Cannot start trial: status is "
                        ++ statusToString other
                        ++ ", expected Awaiting Check-In"
                    )
                ]


completeTrial : ActiveTrial -> Result (List Error) ActiveTrial
completeTrial (ActiveTrial r) =
    case r.status of
        InProgress ->
            Ok (ActiveTrial { r | status = Complete })

        other ->
            Err
                [ Error
                    ("Cannot complete trial: status is "
                        ++ statusToString other
                        ++ ", expected In Progress"
                    )
                ]


verifyTrial : ActiveTrial -> Result (List Error) ActiveTrial
verifyTrial (ActiveTrial r) =
    case r.status of
        Complete ->
            Ok (ActiveTrial { r | status = Verified })

        other ->
            Err
                [ Error
                    ("Cannot verify trial: status is "
                        ++ statusToString other
                        ++ ", expected Complete"
                    )
                ]


statusToString : TrialStatus -> String
statusToString s =
    case s of
        AwaitingCheckIn ->
            "Awaiting Check-In"

        InProgress ->
            "In Progress"

        Complete ->
            "Complete"

        Verified ->
            "Verified"
