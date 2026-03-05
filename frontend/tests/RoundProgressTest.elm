module RoundProgressTest exposing (suite)

import ActiveTrial exposing (TrialStatus(..))
import Assignment exposing (Assignment(..))
import Courtroom
import Expect
import Pairing
import RoundProgress exposing (RoundProgress(..))
import Test exposing (Test, describe, test)
import Team exposing (Team)
import TestHelpers
    exposing
        ( courtroomName
        , teamA
        , teamB
        , teamC
        , testJudge
        )
import Trial


testTrial1 : Trial.Trial
testTrial1 =
    makeTrial teamA teamB "Dept 1"


testTrial2 : Trial.Trial
testTrial2 =
    makeTrial teamA teamC "Dept 2"


makeTrial : Team -> Team -> String -> Trial.Trial
makeTrial pros def room =
    let
        pairing =
            case Pairing.create pros def of
                Ok p ->
                    p

                Err _ ->
                    Debug.todo "pairing must be valid"

        courtroom =
            Courtroom.create (courtroomName room)
    in
    case
        pairing
            |> Pairing.assignCourtroom courtroom
            |> Pairing.assignJudge testJudge
            |> Trial.fromPairing
    of
        Just t ->
            t

        Nothing ->
            Debug.todo "trial must be valid"


advance : ActiveTrial.ActiveTrial -> (ActiveTrial.ActiveTrial -> Result a ActiveTrial.ActiveTrial) -> ActiveTrial.ActiveTrial
advance at fn =
    case fn at of
        Ok next ->
            next

        Err _ ->
            Debug.todo "advance must succeed"


inProgress : Trial.Trial -> ActiveTrial.ActiveTrial
inProgress t =
    ActiveTrial.fromTrial t
        |> (\at -> advance at ActiveTrial.startTrial)


complete : Trial.Trial -> ActiveTrial.ActiveTrial
complete t =
    inProgress t
        |> (\at -> advance at ActiveTrial.completeTrial)


verified : Trial.Trial -> ActiveTrial.ActiveTrial
verified t =
    complete t
        |> (\at -> advance at ActiveTrial.verifyTrial)


suite : Test
suite =
    describe "RoundProgress"
        [ describe "roundProgress"
            [ test "all AwaitingCheckIn -> CheckInOpen" <|
                \_ ->
                    [ ActiveTrial.fromTrial testTrial1
                    , ActiveTrial.fromTrial testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal CheckInOpen
            , test "mixed AwaitingCheckIn + InProgress -> CheckInOpen" <|
                \_ ->
                    [ ActiveTrial.fromTrial testTrial1
                    , inProgress testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal CheckInOpen
            , test "all InProgress -> AllTrialsStarted" <|
                \_ ->
                    [ inProgress testTrial1
                    , inProgress testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal AllTrialsStarted
            , test "mixed InProgress + Complete -> AllTrialsStarted" <|
                \_ ->
                    [ inProgress testTrial1
                    , complete testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal AllTrialsStarted
            , test "all Complete -> AllTrialsComplete" <|
                \_ ->
                    [ complete testTrial1
                    , complete testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal AllTrialsComplete
            , test "mixed Complete + Verified -> AllTrialsComplete" <|
                \_ ->
                    [ complete testTrial1
                    , verified testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal AllTrialsComplete
            , test "all Verified -> FullyVerified" <|
                \_ ->
                    [ verified testTrial1
                    , verified testTrial2
                    ]
                        |> RoundProgress.roundProgress
                        |> Expect.equal FullyVerified
            , test "empty list -> FullyVerified (vacuous truth)" <|
                \_ ->
                    []
                        |> RoundProgress.roundProgress
                        |> Expect.equal FullyVerified
            ]
        , describe "progressToString"
            [ test "CheckInOpen" <|
                \_ ->
                    RoundProgress.progressToString CheckInOpen
                        |> Expect.equal "Check-In Open"
            , test "AllTrialsStarted" <|
                \_ ->
                    RoundProgress.progressToString AllTrialsStarted
                        |> Expect.equal "All Trials Started"
            , test "AllTrialsComplete" <|
                \_ ->
                    RoundProgress.progressToString AllTrialsComplete
                        |> Expect.equal "All Trials Complete"
            , test "FullyVerified" <|
                \_ ->
                    RoundProgress.progressToString FullyVerified
                        |> Expect.equal "Fully Verified"
            ]
        ]
