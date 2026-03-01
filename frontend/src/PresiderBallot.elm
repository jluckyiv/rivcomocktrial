module PresiderBallot exposing
    ( PresiderBallot
    , for
    , winner
    )

import Side exposing (Side)


type PresiderBallot
    = PresiderBallot Side


for : Side -> PresiderBallot
for side =
    PresiderBallot side


winner : PresiderBallot -> Side
winner (PresiderBallot side) =
    side
