module Trial exposing
    ( Trial
    , courtroom
    , defense
    , fromPairing
    , judge
    , prosecution
    )

import Assignment exposing (Assignment(..))
import Courtroom exposing (Courtroom)
import Judge exposing (Judge)
import Pairing
import Team exposing (Team)


type Trial
    = Trial
        { prosecution : Team
        , defense : Team
        , courtroom : Courtroom
        , judge : Judge
        }


fromPairing : Pairing.Pairing -> Maybe Trial
fromPairing pairing =
    case ( Pairing.courtroom pairing, Pairing.judge pairing ) of
        ( Assigned c, Assigned j ) ->
            Just
                (Trial
                    { prosecution = Pairing.prosecution pairing
                    , defense = Pairing.defense pairing
                    , courtroom = c
                    , judge = j
                    }
                )

        _ ->
            Nothing


prosecution : Trial -> Team
prosecution (Trial r) =
    r.prosecution


defense : Trial -> Team
defense (Trial r) =
    r.defense


courtroom : Trial -> Courtroom
courtroom (Trial r) =
    r.courtroom


judge : Trial -> Judge
judge (Trial r) =
    r.judge
