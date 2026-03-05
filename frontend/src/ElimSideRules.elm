module ElimSideRules exposing
    ( MeetingHistory(..)
    , elimSide
    , elimSideAssignment
    , meetingHistory
    )

import Error exposing (Error(..))
import Side exposing (Side(..))
import Team exposing (Team)
import Trial exposing (Trial)


type MeetingHistory
    = FirstMeeting { mostRecentSide : Side }
    | Rematch { priorSide : Side }
    | ThirdMeeting


meetingHistory :
    Team
    -> Team
    -> List Trial
    -> Side
    -> MeetingHistory
meetingHistory higherSeed lowerSeed trials mostRecentSide =
    let
        priorMeetings =
            List.filter (involves higherSeed lowerSeed) trials
    in
    case List.length priorMeetings of
        0 ->
            FirstMeeting { mostRecentSide = mostRecentSide }

        _ ->
            case priorMeetings of
                [ trial ] ->
                    let
                        priorSide =
                            if isTeam higherSeed (Trial.prosecution trial) then
                                Prosecution

                            else
                                Defense
                    in
                    Rematch { priorSide = priorSide }

                _ ->
                    ThirdMeeting


elimSide : MeetingHistory -> Result (List Error) Side
elimSide history =
    case history of
        FirstMeeting { mostRecentSide } ->
            Ok (flip mostRecentSide)

        Rematch { priorSide } ->
            Ok (flip priorSide)

        ThirdMeeting ->
            Err [ Error "Coin flip required for third meeting" ]


elimSideAssignment :
    MeetingHistory
    -> Result (List Error) ( Side, Side )
elimSideAssignment history =
    elimSide history
        |> Result.map
            (\higherSeedSide ->
                ( higherSeedSide, flip higherSeedSide )
            )


flip : Side -> Side
flip side =
    case side of
        Prosecution ->
            Defense

        Defense ->
            Prosecution


involves : Team -> Team -> Trial -> Bool
involves a b trial =
    let
        p =
            Trial.prosecution trial

        d =
            Trial.defense trial
    in
    (isTeam a p && isTeam b d)
        || (isTeam b p && isTeam a d)


isTeam : Team -> Team -> Bool
isTeam a b =
    Team.numberToInt (Team.teamNumber a)
        == Team.numberToInt (Team.teamNumber b)
