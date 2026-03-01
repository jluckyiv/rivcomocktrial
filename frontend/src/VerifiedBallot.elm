module VerifiedBallot exposing
    ( VerifiedBallot
    , verify
    , verifyWithCorrections
    )

import SubmittedBallot
    exposing
        ( ScoredPresentation
        , SubmittedBallot
        )


type alias VerifiedBallot =
    { original : SubmittedBallot
    , presentations : List ScoredPresentation
    }


verify : SubmittedBallot -> VerifiedBallot
verify ballot =
    { original = ballot
    , presentations = ballot.presentations
    }


verifyWithCorrections :
    SubmittedBallot
    -> List ScoredPresentation
    -> VerifiedBallot
verifyWithCorrections ballot corrected =
    { original = ballot
    , presentations = corrected
    }
