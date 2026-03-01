module Pairing exposing
    ( Pairing
    , assignCourtroom
    , assignJudge
    , create
    )

import Assignment exposing (Assignment(..))
import Courtroom exposing (Courtroom)
import Judge exposing (Judge)
import Team exposing (Team)


type alias Pairing =
    { prosecution : Team
    , defense : Team
    , courtroom : Assignment Courtroom
    , judge : Assignment Judge
    }


create : Team -> Team -> Pairing
create prosecution defense =
    { prosecution = prosecution
    , defense = defense
    , courtroom = NotAssigned
    , judge = NotAssigned
    }


assignCourtroom : Courtroom -> Pairing -> Pairing
assignCourtroom courtroom pairing =
    { pairing | courtroom = Assigned courtroom }


assignJudge : Judge -> Pairing -> Pairing
assignJudge judge pairing =
    { pairing | judge = Assigned judge }
