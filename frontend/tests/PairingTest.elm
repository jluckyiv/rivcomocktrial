module PairingTest exposing (suite)

import Assignment exposing (Assignment(..))
import Courtroom
import Expect
import Judge
import Pairing
import Test exposing (Test, describe, test)
import TestHelpers exposing (courtroomName, teamA, teamB, testJudge)


suite : Test
suite =
    describe "Pairing"
        [ describe "create"
            [ test "succeeds with different teams" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> isOk
                        |> Expect.equal True
            , test "sets prosecution team" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Result.map Pairing.prosecution
                        |> Expect.equal (Ok teamA)
            , test "sets defense team" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Result.map Pairing.defense
                        |> Expect.equal (Ok teamB)
            , test "courtroom is NotAssigned" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Result.map Pairing.courtroom
                        |> Expect.equal (Ok NotAssigned)
            , test "judge is NotAssigned" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Result.map Pairing.judge
                        |> Expect.equal (Ok NotAssigned)
            , test "rejects same team as both sides" <|
                \_ ->
                    Pairing.create teamA teamA
                        |> isErr
                        |> Expect.equal True
            ]
        , describe "assignCourtroom"
            [ test "sets the courtroom" <|
                \_ ->
                    let
                        cr =
                            Courtroom.create (courtroomName "Dept 1")
                    in
                    Pairing.create teamA teamB
                        |> Result.map (Pairing.assignCourtroom cr)
                        |> Result.map Pairing.courtroom
                        |> Expect.equal (Ok (Assigned cr))
            ]
        , describe "assignJudge"
            [ test "sets the judge" <|
                \_ ->
                    Pairing.create teamA teamB
                        |> Result.map (Pairing.assignJudge testJudge)
                        |> Result.map Pairing.judge
                        |> Expect.equal (Ok (Assigned testJudge))
            ]
        ]


isOk : Result e a -> Bool
isOk result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


isErr : Result e a -> Bool
isErr result =
    not (isOk result)
