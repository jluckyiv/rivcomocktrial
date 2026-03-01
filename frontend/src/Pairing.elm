module Pairing exposing
    ( Pairing
    , assignCourtroom
    , assignJudge
    , courtroom
    , create
    , defense
    , judge
    , prosecution
    )

import Assignment exposing (Assignment(..))
import Error exposing (Error(..))
import Courtroom exposing (Courtroom)
import Judge exposing (Judge)
import Team exposing (Team)


type Pairing
    = Pairing
        { prosecution : Team
        , defense : Team
        , courtroom : Assignment Courtroom
        , judge : Assignment Judge
        }


create : Team -> Team -> Result Error Pairing
create p d =
    if p == d then
        Err (Error "Cannot pair a team against itself")

    else
        Ok
            (Pairing
                { prosecution = p
                , defense = d
                , courtroom = NotAssigned
                , judge = NotAssigned
                }
            )


prosecution : Pairing -> Team
prosecution (Pairing r) =
    r.prosecution


defense : Pairing -> Team
defense (Pairing r) =
    r.defense


courtroom : Pairing -> Assignment Courtroom
courtroom (Pairing r) =
    r.courtroom


judge : Pairing -> Assignment Judge
judge (Pairing r) =
    r.judge


assignCourtroom : Courtroom -> Pairing -> Pairing
assignCourtroom c (Pairing r) =
    Pairing { r | courtroom = Assigned c }


assignJudge : Judge -> Pairing -> Pairing
assignJudge j (Pairing r) =
    Pairing { r | judge = Assigned j }
