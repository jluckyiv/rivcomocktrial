module ElimSideRulesTest exposing (suite)

import ElimSideRules exposing (MeetingHistory(..))
import Error exposing (Error(..))
import Expect
import Side exposing (Side(..))
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( teamA
        , teamB
        , teamC
        , trialFor
        )


suite : Test
suite =
    describe "ElimSideRules"
        [ meetingHistoryTests
        , elimSideTests
        , elimSideAssignmentTests
        , integrationTests
        ]


meetingHistoryTests : Test
meetingHistoryTests =
    describe "meetingHistory"
        [ test "no prior trials → FirstMeeting with mostRecentSide" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    []
                    Prosecution
                    |> Expect.equal
                        (FirstMeeting { mostRecentSide = Prosecution })
        , test "one trial where higher seed was P → Rematch { P }" <|
            \_ ->
                -- teamA is prosecution in this trial
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamA teamB ]
                    Prosecution
                    |> Expect.equal
                        (Rematch { priorSide = Prosecution })
        , test "one trial where higher seed was D → Rematch { D }" <|
            \_ ->
                -- teamA is defense (teamB is prosecution)
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamB teamA ]
                    Prosecution
                    |> Expect.equal
                        (Rematch { priorSide = Defense })
        , test "two trials → ThirdMeeting" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamA teamB
                    , trialFor teamB teamA
                    ]
                    Prosecution
                    |> Expect.equal ThirdMeeting
        , test "unrelated trials excluded" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamA teamC ]
                    Prosecution
                    |> Expect.equal
                        (FirstMeeting { mostRecentSide = Prosecution })
        ]


elimSideTests : Test
elimSideTests =
    describe "elimSide"
        [ test "FirstMeeting { P } → Ok D (flip)" <|
            \_ ->
                ElimSideRules.elimSide
                    (FirstMeeting { mostRecentSide = Prosecution })
                    |> Expect.equal (Ok Defense)
        , test "FirstMeeting { D } → Ok P (flip)" <|
            \_ ->
                ElimSideRules.elimSide
                    (FirstMeeting { mostRecentSide = Defense })
                    |> Expect.equal (Ok Prosecution)
        , test "Rematch { P } → Ok D (flip)" <|
            \_ ->
                ElimSideRules.elimSide
                    (Rematch { priorSide = Prosecution })
                    |> Expect.equal (Ok Defense)
        , test "Rematch { D } → Ok P (flip)" <|
            \_ ->
                ElimSideRules.elimSide
                    (Rematch { priorSide = Defense })
                    |> Expect.equal (Ok Prosecution)
        , test "ThirdMeeting → Err" <|
            \_ ->
                ElimSideRules.elimSide ThirdMeeting
                    |> Expect.err
        ]


elimSideAssignmentTests : Test
elimSideAssignmentTests =
    describe "elimSideAssignment"
        [ test "FirstMeeting { P } → Ok (D, P)" <|
            \_ ->
                ElimSideRules.elimSideAssignment
                    (FirstMeeting { mostRecentSide = Prosecution })
                    |> Expect.equal (Ok ( Defense, Prosecution ))
        , test "FirstMeeting { D } → Ok (P, D)" <|
            \_ ->
                ElimSideRules.elimSideAssignment
                    (FirstMeeting { mostRecentSide = Defense })
                    |> Expect.equal (Ok ( Prosecution, Defense ))
        , test "ThirdMeeting → Err propagated" <|
            \_ ->
                ElimSideRules.elimSideAssignment ThirdMeeting
                    |> Expect.err
        ]


integrationTests : Test
integrationTests =
    describe "meetingHistory → elimSideAssignment end-to-end"
        [ test "first meeting as P → assigned D for elim" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    []
                    Prosecution
                    |> ElimSideRules.elimSideAssignment
                    |> Expect.equal (Ok ( Defense, Prosecution ))
        , test "rematch after being P → assigned D for elim" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamA teamB ]
                    Prosecution
                    |> ElimSideRules.elimSideAssignment
                    |> Expect.equal (Ok ( Defense, Prosecution ))
        , test "third meeting → coin flip required" <|
            \_ ->
                ElimSideRules.meetingHistory
                    teamA
                    teamB
                    [ trialFor teamA teamB
                    , trialFor teamB teamA
                    ]
                    Prosecution
                    |> ElimSideRules.elimSideAssignment
                    |> Expect.err
        ]
