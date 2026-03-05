module RoundProgress exposing
    ( RoundProgress(..)
    , progressToString
    , roundProgress
    )

import ActiveTrial exposing (ActiveTrial, TrialStatus(..))


type RoundProgress
    = CheckInOpen
    | AllTrialsStarted
    | AllTrialsComplete
    | FullyVerified


roundProgress : List ActiveTrial -> RoundProgress
roundProgress trials =
    let
        statuses =
            List.map ActiveTrial.status trials
    in
    if List.any ((==) AwaitingCheckIn) statuses then
        CheckInOpen

    else if List.any ((==) InProgress) statuses then
        AllTrialsStarted

    else if List.any ((==) Complete) statuses then
        AllTrialsComplete

    else
        FullyVerified


progressToString : RoundProgress -> String
progressToString p =
    case p of
        CheckInOpen ->
            "Check-In Open"

        AllTrialsStarted ->
            "All Trials Started"

        AllTrialsComplete ->
            "All Trials Complete"

        FullyVerified ->
            "Fully Verified"
