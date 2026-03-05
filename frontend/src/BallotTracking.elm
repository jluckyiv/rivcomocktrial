module BallotTracking exposing
    ( BallotTracking
    , PresiderStatus(..)
    , ScorerStatus(..)
    , create
    , expectedScorers
    , presiderBallot
    , presiderStatus
    , replaceVerifiedBallot
    , scorerStatus
    , submitBallot
    , submitPresiderBallot
    , submitted
    , trial
    , verified
    , verifyBallot
    )

import Error exposing (Error(..))
import PresiderBallot exposing (PresiderBallot)
import SubmittedBallot exposing (SubmittedBallot)
import Trial exposing (Trial)
import VerifiedBallot exposing (VerifiedBallot)
import Volunteer exposing (Volunteer)


type ScorerStatus
    = AwaitingSubmissions (List Volunteer)
    | AwaitingVerification
    | AllVerified


type PresiderStatus
    = AwaitingPresiderBallot
    | PresiderBallotReceived


type BallotTracking
    = BallotTracking
        { trial : Trial
        , expectedScorers : List Volunteer
        , submitted : List ( Volunteer, SubmittedBallot )
        , verified : List ( Volunteer, VerifiedBallot )
        , presiderBallot : Maybe PresiderBallot
        }


create : Trial -> List Volunteer -> BallotTracking
create t scorers =
    BallotTracking
        { trial = t
        , expectedScorers = scorers
        , submitted = []
        , verified = []
        , presiderBallot = Nothing
        }


trial : BallotTracking -> Trial
trial (BallotTracking r) =
    r.trial


expectedScorers : BallotTracking -> List Volunteer
expectedScorers (BallotTracking r) =
    r.expectedScorers


submitted : BallotTracking -> List ( Volunteer, SubmittedBallot )
submitted (BallotTracking r) =
    r.submitted


verified : BallotTracking -> List ( Volunteer, VerifiedBallot )
verified (BallotTracking r) =
    r.verified


presiderBallot : BallotTracking -> Maybe PresiderBallot
presiderBallot (BallotTracking r) =
    r.presiderBallot


submitBallot :
    Volunteer
    -> SubmittedBallot
    -> BallotTracking
    -> Result (List Error) BallotTracking
submitBallot vol ballot (BallotTracking r) =
    if not (List.member vol r.expectedScorers) then
        Err [ Error "Volunteer is not an expected scorer" ]

    else if List.any (\( v, _ ) -> v == vol) r.submitted then
        Err [ Error "Volunteer has already submitted a ballot" ]

    else
        Ok
            (BallotTracking
                { r
                    | submitted =
                        r.submitted ++ [ ( vol, ballot ) ]
                }
            )


verifyBallot :
    Volunteer
    -> VerifiedBallot
    -> BallotTracking
    -> Result (List Error) BallotTracking
verifyBallot vol ballot (BallotTracking r) =
    if not (List.any (\( v, _ ) -> v == vol) r.submitted) then
        Err [ Error "Volunteer has no submitted ballot to verify" ]

    else if List.any (\( v, _ ) -> v == vol) r.verified then
        Err [ Error "Volunteer ballot has already been verified" ]

    else
        Ok
            (BallotTracking
                { r
                    | verified =
                        r.verified ++ [ ( vol, ballot ) ]
                }
            )


replaceVerifiedBallot :
    Volunteer
    -> VerifiedBallot
    -> BallotTracking
    -> Result (List Error) BallotTracking
replaceVerifiedBallot vol ballot (BallotTracking r) =
    if not (List.any (\( v, _ ) -> v == vol) r.verified) then
        Err [ Error "Volunteer has no verified ballot to replace" ]

    else
        Ok
            (BallotTracking
                { r
                    | verified =
                        List.map
                            (\( v, b ) ->
                                if v == vol then
                                    ( v, ballot )

                                else
                                    ( v, b )
                            )
                            r.verified
                }
            )


submitPresiderBallot :
    PresiderBallot
    -> BallotTracking
    -> Result (List Error) BallotTracking
submitPresiderBallot ballot (BallotTracking r) =
    case r.presiderBallot of
        Just _ ->
            Err [ Error "Presider ballot has already been submitted" ]

        Nothing ->
            Ok (BallotTracking { r | presiderBallot = Just ballot })


scorerStatus : BallotTracking -> ScorerStatus
scorerStatus (BallotTracking r) =
    let
        submittedVolunteers =
            List.map Tuple.first r.submitted

        missing =
            List.filter
                (\v -> not (List.member v submittedVolunteers))
                r.expectedScorers
    in
    if not (List.isEmpty missing) then
        AwaitingSubmissions missing

    else if List.length r.verified < List.length r.submitted then
        AwaitingVerification

    else
        AllVerified


presiderStatus : BallotTracking -> PresiderStatus
presiderStatus (BallotTracking r) =
    case r.presiderBallot of
        Nothing ->
            AwaitingPresiderBallot

        Just _ ->
            PresiderBallotReceived
