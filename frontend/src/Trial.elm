module Trial exposing (Trial, fromPairing)

import Assignment exposing (Assignment(..))
import Courtroom exposing (Courtroom)
import Judge exposing (Judge)
import Pairing exposing (Pairing)
import Team exposing (Team)


type alias Trial =
    { prosecution : Team
    , defense : Team
    , courtroom : Courtroom
    , judge : Judge
    }


fromPairing : Pairing -> Maybe Trial
fromPairing pairing =
    case ( pairing.courtroom, pairing.judge ) of
        ( Assigned c, Assigned j ) ->
            Just
                { prosecution = pairing.prosecution
                , defense = pairing.defense
                , courtroom = c
                , judge = j
                }

        _ ->
            Nothing
