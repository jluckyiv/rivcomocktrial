module VolunteerSlot exposing
    ( VolunteerSlot
    , VolunteerStatus(..)
    , checkIn
    , courtroomOf
    , isCheckedIn
    , isPresent
    , isTentative
    , reportForDuty
    , round
    , status
    , tentative
    , validateCheckIn
    , volunteer
    , walkUp
    , walkUpDirect
    )

import Conflict
    exposing
        ( HardConflict
        , SoftConflict
        )
import Courtroom exposing (Courtroom)
import Error exposing (Error(..))
import Round exposing (Round)
import Team exposing (Team)
import Trial exposing (Trial)
import Volunteer exposing (Volunteer)


type VolunteerStatus
    = Tentative Courtroom
    | Present
    | CheckedIn Courtroom


type VolunteerSlot
    = VolunteerSlot
        { volunteer : Volunteer
        , round : Round
        , status : VolunteerStatus
        }


tentative : Volunteer -> Round -> Courtroom -> VolunteerSlot
tentative vol r courtroom =
    VolunteerSlot
        { volunteer = vol
        , round = r
        , status = Tentative courtroom
        }


walkUp : Volunteer -> Round -> VolunteerSlot
walkUp vol r =
    VolunteerSlot
        { volunteer = vol
        , round = r
        , status = Present
        }


walkUpDirect : Volunteer -> Round -> Courtroom -> VolunteerSlot
walkUpDirect vol r courtroom =
    VolunteerSlot
        { volunteer = vol
        , round = r
        , status = CheckedIn courtroom
        }


reportForDuty : VolunteerSlot -> VolunteerSlot
reportForDuty (VolunteerSlot r) =
    case r.status of
        Tentative _ ->
            VolunteerSlot { r | status = Present }

        _ ->
            VolunteerSlot r


checkIn : Courtroom -> VolunteerSlot -> VolunteerSlot
checkIn courtroom (VolunteerSlot r) =
    VolunteerSlot { r | status = CheckedIn courtroom }


volunteer : VolunteerSlot -> Volunteer
volunteer (VolunteerSlot r) =
    r.volunteer


round : VolunteerSlot -> Round
round (VolunteerSlot r) =
    r.round


status : VolunteerSlot -> VolunteerStatus
status (VolunteerSlot r) =
    r.status


courtroomOf : VolunteerStatus -> Maybe Courtroom
courtroomOf s =
    case s of
        Tentative c ->
            Just c

        Present ->
            Nothing

        CheckedIn c ->
            Just c


isCheckedIn : VolunteerSlot -> Bool
isCheckedIn (VolunteerSlot r) =
    case r.status of
        CheckedIn _ ->
            True

        _ ->
            False


isTentative : VolunteerSlot -> Bool
isTentative (VolunteerSlot r) =
    case r.status of
        Tentative _ ->
            True

        _ ->
            False


isPresent : VolunteerSlot -> Bool
isPresent (VolunteerSlot r) =
    case r.status of
        Present ->
            True

        _ ->
            False


validateCheckIn :
    VolunteerSlot
    -> Trial
    -> List HardConflict
    -> List ( Round, Team, Team )
    -> Result (List Error) ( VolunteerSlot, List SoftConflict )
validateCheckIn slot trial_ hardConflicts history =
    let
        prosecution =
            Trial.prosecution trial_

        defense =
            Trial.defense trial_

        courtroom =
            Trial.courtroom trial_

        vol =
            volunteer slot

        matchingHard =
            Conflict.checkHardConflicts hardConflicts prosecution defense

        softConflicts =
            Conflict.checkSoftConflicts vol history prosecution defense
    in
    if List.isEmpty matchingHard then
        Ok ( checkIn courtroom slot, softConflicts )

    else
        Err
            (List.map
                (\_ -> Error "Hard conflict blocks check-in")
                matchingHard
            )
