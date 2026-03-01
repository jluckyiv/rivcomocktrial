module PresiderBallot exposing
    ( PresiderBallot
    , for
    , winner
    )

import Side exposing (Side)


type alias PresiderBallot =
    { winner : Side }


for : Side -> PresiderBallot
for side =
    { winner = side }


winner : PresiderBallot -> Side
winner ballot =
    ballot.winner
