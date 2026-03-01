module PresiderBallotTest exposing (suite)

import Expect
import PresiderBallot
import Side exposing (Side(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "PresiderBallot"
        [ test "for Prosecution creates ballot with Prosecution winner" <|
            \_ ->
                PresiderBallot.for Prosecution
                    |> PresiderBallot.winner
                    |> Expect.equal Prosecution
        , test "for Defense creates ballot with Defense winner" <|
            \_ ->
                PresiderBallot.for Defense
                    |> PresiderBallot.winner
                    |> Expect.equal Defense
        ]
