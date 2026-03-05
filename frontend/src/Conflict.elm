module Conflict exposing
    ( Conflict(..)
    , ConflictSubject(..)
    , HardConflict
    , SoftConflict
    , checkHardConflicts
    , checkSoftConflicts
    , hardConflict
    , hardConflictSubject
    , hardConflictVolunteer
    , softConflict
    , softConflictRound
    , softConflictTeam
    , softConflictVolunteer
    )

import Round exposing (Round)
import School exposing (School)
import Team exposing (Team)
import Volunteer exposing (Volunteer)


type ConflictSubject
    = WithTeam Team
    | WithSchool School


type HardConflict
    = HardConflict { volunteer : Volunteer, subject : ConflictSubject }


hardConflict : Volunteer -> ConflictSubject -> HardConflict
hardConflict vol subject =
    HardConflict { volunteer = vol, subject = subject }


hardConflictVolunteer : HardConflict -> Volunteer
hardConflictVolunteer (HardConflict r) =
    r.volunteer


hardConflictSubject : HardConflict -> ConflictSubject
hardConflictSubject (HardConflict r) =
    r.subject


type SoftConflict
    = SoftConflict { volunteer : Volunteer, team : Team, round : Round }


softConflict : Volunteer -> Team -> Round -> SoftConflict
softConflict vol team round =
    SoftConflict { volunteer = vol, team = team, round = round }


softConflictVolunteer : SoftConflict -> Volunteer
softConflictVolunteer (SoftConflict r) =
    r.volunteer


softConflictTeam : SoftConflict -> Team
softConflictTeam (SoftConflict r) =
    r.team


softConflictRound : SoftConflict -> Round
softConflictRound (SoftConflict r) =
    r.round


type Conflict
    = Hard HardConflict
    | Soft SoftConflict


checkHardConflicts : List HardConflict -> Team -> Team -> List HardConflict
checkHardConflicts conflicts prosecution defense =
    List.filter (matchesHard prosecution defense) conflicts


matchesHard : Team -> Team -> HardConflict -> Bool
matchesHard prosecution defense (HardConflict r) =
    case r.subject of
        WithTeam team ->
            team == prosecution || team == defense

        WithSchool school ->
            Team.school prosecution == school || Team.school defense == school


checkSoftConflicts :
    Volunteer
    -> List ( Round, Team, Team )
    -> Team
    -> Team
    -> List SoftConflict
checkSoftConflicts vol history prosecution defense =
    let
        currentTeams =
            [ prosecution, defense ]
    in
    List.concatMap (findSoftConflicts vol currentTeams) history


findSoftConflicts :
    Volunteer
    -> List Team
    -> ( Round, Team, Team )
    -> List SoftConflict
findSoftConflicts vol currentTeams ( round, histProsecution, histDefense ) =
    let
        historyTeams =
            [ histProsecution, histDefense ]

        overlapping =
            List.filter (\t -> List.member t historyTeams) currentTeams
    in
    List.map (\team -> softConflict vol team round) overlapping
