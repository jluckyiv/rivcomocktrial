module PairingTest exposing (suite)

import Assignment exposing (Assignment(..))
import Courtroom
import Expect
import Judge exposing (Judge(..))
import Pairing
import Test exposing (Test, describe, test)
import TestHelpers exposing (teamA, teamB)


suite : Test
suite =
    describe "Pairing"
        [ describe "create"
            [ test "sets prosecution team" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> .prosecution
                        |> Expect.equal teamA
            , test "sets defense team" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> .defense
                        |> Expect.equal teamB
            , test "courtroom is NotAssigned" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> .courtroom
                        |> Expect.equal NotAssigned
            , test "judge is NotAssigned" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> .judge
                        |> Expect.equal NotAssigned
            ]
        , describe "assignCourtroom"
            [ test "sets the courtroom" <|
                \_ ->
                    let
                        courtroom =
                            { name = Courtroom.name "Dept 1" }
                    in
                    Pairing.create teamA teamB
                        |> Pairing.assignCourtroom courtroom
                        |> .courtroom
                        |> Expect.equal (Assigned courtroom)
            ]
        , describe "assignJudge"
            [ test "sets the judge" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Pairing.assignJudge Judge
                        |> .judge
                        |> Expect.equal (Assigned Judge)
            ]
        ]
