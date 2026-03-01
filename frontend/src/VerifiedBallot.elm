module VerifiedBallot exposing
    ( VerifiedBallot
    , original
    , presentations
    , verify
    , verifyWithCorrections
    )

import SubmittedBallot
    exposing
        ( ScoredPresentation
        , SubmittedBallot
        )


type VerifiedBallot
    = VerifiedBallot
        { original : SubmittedBallot
        , presentations : List ScoredPresentation
        }


verify : SubmittedBallot -> VerifiedBallot
verify ballot =
    VerifiedBallot
        { original = ballot
        , presentations = SubmittedBallot.presentations ballot
        }


verifyWithCorrections :
    SubmittedBallot
    -> List ScoredPresentation
    -> VerifiedBallot
verifyWithCorrections ballot corrected =
    VerifiedBallot
        { original = ballot
        , presentations = corrected
        }


original : VerifiedBallot -> SubmittedBallot
original (VerifiedBallot r) =
    r.original


presentations : VerifiedBallot -> List ScoredPresentation
presentations (VerifiedBallot r) =
    r.presentations
