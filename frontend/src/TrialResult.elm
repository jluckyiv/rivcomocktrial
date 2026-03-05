module TrialResult exposing
    ( TrialResult
    , aggregate
    , defense
    , defensePoints
    , headToHead
    , prosecution
    , prosecutionPoints
    , trialResult
    , winner
    )

import Dict exposing (Dict)
import Error exposing (Error(..))
import PrelimResult
import PresiderBallot exposing (PresiderBallot)
import Side exposing (Side(..))
import Standings
import Team exposing (Team)
import Trial exposing (Trial)
import Validate
import VerifiedBallot exposing (VerifiedBallot)


type TrialResult
    = TrialResult
        { prosecution : Team
        , defense : Team
        , prosecutionPoints : Int
        , defensePoints : Int
        , winner : Side
        }


trialResult :
    Trial
    -> List VerifiedBallot
    -> Maybe PresiderBallot
    -> Result (List Error) TrialResult
trialResult trial ballots maybePresider =
    Validate.validate
        (Validate.ifEmptyList identity
            (Error "Cannot determine result from empty ballot list")
        )
        ballots
        |> Result.andThen
            (\valid ->
                let
                    validBallots =
                        Validate.fromValid valid

                    pPoints =
                        List.map (PrelimResult.courtTotal Prosecution)
                            validBallots
                            |> List.sum

                    dPoints =
                        List.map (PrelimResult.courtTotal Defense)
                            validBallots
                            |> List.sum
                in
                determineWinner pPoints dPoints maybePresider
                    |> Result.map
                        (\w ->
                            TrialResult
                                { prosecution = Trial.prosecution trial
                                , defense = Trial.defense trial
                                , prosecutionPoints = pPoints
                                , defensePoints = dPoints
                                , winner = w
                                }
                        )
            )


determineWinner :
    Int
    -> Int
    -> Maybe PresiderBallot
    -> Result (List Error) Side
determineWinner pPoints dPoints maybePresider =
    if pPoints > dPoints then
        Ok Prosecution

    else if dPoints > pPoints then
        Ok Defense

    else
        case maybePresider of
            Just presider ->
                Ok (PresiderBallot.winner presider)

            Nothing ->
                Err
                    [ Error
                        "Scores are tied and no presider ballot provided"
                    ]


prosecution : TrialResult -> Team
prosecution (TrialResult r) =
    r.prosecution


defense : TrialResult -> Team
defense (TrialResult r) =
    r.defense


prosecutionPoints : TrialResult -> Int
prosecutionPoints (TrialResult r) =
    r.prosecutionPoints


defensePoints : TrialResult -> Int
defensePoints (TrialResult r) =
    r.defensePoints


winner : TrialResult -> Side
winner (TrialResult r) =
    r.winner


aggregate :
    List TrialResult
    -> List ( Team, Standings.TeamRecord )
aggregate results =
    List.foldl addResult Dict.empty results
        |> Dict.values
        |> List.map
            (\( team, rec ) ->
                ( team, Standings.teamRecord rec )
            )


addResult :
    TrialResult
    -> Dict String ( Team, { wins : Int, losses : Int, pointsFor : Int, pointsAgainst : Int } )
    -> Dict String ( Team, { wins : Int, losses : Int, pointsFor : Int, pointsAgainst : Int } )
addResult (TrialResult r) acc =
    let
        pKey =
            teamKey r.prosecution

        dKey =
            teamKey r.defense

        ( pWin, dWin ) =
            case r.winner of
                Prosecution ->
                    ( 1, 0 )

                Defense ->
                    ( 0, 1 )
    in
    acc
        |> upsert pKey
            r.prosecution
            { wins = pWin
            , losses = 1 - pWin
            , pointsFor = r.prosecutionPoints
            , pointsAgainst = r.defensePoints
            }
        |> upsert dKey
            r.defense
            { wins = dWin
            , losses = 1 - dWin
            , pointsFor = r.defensePoints
            , pointsAgainst = r.prosecutionPoints
            }


upsert :
    String
    -> Team
    -> { wins : Int, losses : Int, pointsFor : Int, pointsAgainst : Int }
    -> Dict String ( Team, { wins : Int, losses : Int, pointsFor : Int, pointsAgainst : Int } )
    -> Dict String ( Team, { wins : Int, losses : Int, pointsFor : Int, pointsAgainst : Int } )
upsert key team delta acc =
    let
        existing =
            Dict.get key acc
                |> Maybe.map Tuple.second
                |> Maybe.withDefault
                    { wins = 0
                    , losses = 0
                    , pointsFor = 0
                    , pointsAgainst = 0
                    }
    in
    Dict.insert key
        ( team
        , { wins = existing.wins + delta.wins
          , losses = existing.losses + delta.losses
          , pointsFor = existing.pointsFor + delta.pointsFor
          , pointsAgainst =
                existing.pointsAgainst + delta.pointsAgainst
          }
        )
        acc


teamKey : Team -> String
teamKey team =
    String.fromInt (Team.numberToInt (Team.teamNumber team))


headToHead :
    Team
    -> Team
    -> List TrialResult
    -> { wins : Int, losses : Int }
headToHead teamOne teamTwo results =
    let
        relevant =
            List.filter (involvesTeams teamOne teamTwo) results
    in
    List.foldl
        (\(TrialResult r) acc ->
            if isTeam teamOne r.prosecution then
                case r.winner of
                    Prosecution ->
                        { acc | wins = acc.wins + 1 }

                    Defense ->
                        { acc | losses = acc.losses + 1 }

            else
                case r.winner of
                    Prosecution ->
                        { acc | losses = acc.losses + 1 }

                    Defense ->
                        { acc | wins = acc.wins + 1 }
        )
        { wins = 0, losses = 0 }
        relevant


involvesTeams : Team -> Team -> TrialResult -> Bool
involvesTeams a b (TrialResult r) =
    (isTeam a r.prosecution && isTeam b r.defense)
        || (isTeam b r.prosecution && isTeam a r.defense)


isTeam : Team -> Team -> Bool
isTeam a b =
    Team.numberToInt (Team.teamNumber a)
        == Team.numberToInt (Team.teamNumber b)
