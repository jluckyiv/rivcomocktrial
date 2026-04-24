module VolunteerSlotTest exposing (suite)

import Conflict exposing (ConflictSubject(..))
import Expect
import Round exposing (Round(..))
import Test exposing (Test, describe, test)
import TestHelpers
    exposing
        ( courtroomA
        , courtroomB
        , teamA
        , teamC
        , testScorer
        , testTrial
        )
import VolunteerSlot exposing (VolunteerStatus(..))


suite : Test
suite =
    describe "VolunteerSlot"
        [ creationTests
        , transitionTests
        , accessorTests
        , conflictValidationTests
        ]


creationTests : Test
creationTests =
    describe "creation"
        [ test "tentative preserves volunteer" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.volunteer
                    |> Expect.equal testScorer
        , test "tentative preserves round" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.round
                    |> Expect.equal Preliminary1
        , test "tentative has Tentative status with courtroom" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.status
                    |> Expect.equal (Tentative courtroomA)
        , test "walkUp creates with Present status" <|
            \_ ->
                VolunteerSlot.walkUp testScorer Preliminary1
                    |> VolunteerSlot.status
                    |> Expect.equal Present
        , test "walkUpDirect creates with CheckedIn + courtroom" <|
            \_ ->
                VolunteerSlot.walkUpDirect testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.status
                    |> Expect.equal (CheckedIn courtroomA)
        ]


transitionTests : Test
transitionTests =
    describe "transitions"
        [ test "Tentative -> reportForDuty -> Present" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.reportForDuty
                    |> VolunteerSlot.status
                    |> Expect.equal Present
        , test "Present -> checkIn courtroom -> CheckedIn" <|
            \_ ->
                VolunteerSlot.walkUp testScorer Preliminary1
                    |> VolunteerSlot.checkIn courtroomA
                    |> VolunteerSlot.status
                    |> Expect.equal (CheckedIn courtroomA)
        , test "Tentative -> checkIn courtroom -> CheckedIn (skip Present)" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.checkIn courtroomB
                    |> VolunteerSlot.status
                    |> Expect.equal (CheckedIn courtroomB)
        , test "CheckedIn A -> checkIn B -> CheckedIn B (reassign)" <|
            \_ ->
                VolunteerSlot.walkUpDirect testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.checkIn courtroomB
                    |> VolunteerSlot.status
                    |> Expect.equal (CheckedIn courtroomB)
        , test "reportForDuty on Present is no-op" <|
            \_ ->
                VolunteerSlot.walkUp testScorer Preliminary1
                    |> VolunteerSlot.reportForDuty
                    |> VolunteerSlot.status
                    |> Expect.equal Present
        , test "reportForDuty on CheckedIn is no-op" <|
            \_ ->
                VolunteerSlot.walkUpDirect testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.reportForDuty
                    |> VolunteerSlot.status
                    |> Expect.equal (CheckedIn courtroomA)
        ]


accessorTests : Test
accessorTests =
    describe "accessors"
        [ test "courtroomOf Tentative -> Just" <|
            \_ ->
                VolunteerSlot.courtroomOf (Tentative courtroomA)
                    |> Expect.equal (Just courtroomA)
        , test "courtroomOf Present -> Nothing" <|
            \_ ->
                VolunteerSlot.courtroomOf Present
                    |> Expect.equal Nothing
        , test "courtroomOf CheckedIn -> Just" <|
            \_ ->
                VolunteerSlot.courtroomOf (CheckedIn courtroomA)
                    |> Expect.equal (Just courtroomA)
        , test "isCheckedIn true for CheckedIn" <|
            \_ ->
                VolunteerSlot.walkUpDirect testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.isCheckedIn
                    |> Expect.equal True
        , test "isCheckedIn false for Tentative" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.isCheckedIn
                    |> Expect.equal False
        , test "isTentative true for Tentative" <|
            \_ ->
                VolunteerSlot.tentative testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.isTentative
                    |> Expect.equal True
        , test "isTentative false for Present" <|
            \_ ->
                VolunteerSlot.walkUp testScorer Preliminary1
                    |> VolunteerSlot.isTentative
                    |> Expect.equal False
        , test "isPresent true for Present" <|
            \_ ->
                VolunteerSlot.walkUp testScorer Preliminary1
                    |> VolunteerSlot.isPresent
                    |> Expect.equal True
        , test "isPresent false for CheckedIn" <|
            \_ ->
                VolunteerSlot.walkUpDirect testScorer Preliminary1 courtroomA
                    |> VolunteerSlot.isPresent
                    |> Expect.equal False
        ]


conflictValidationTests : Test
conflictValidationTests =
    describe "validateCheckIn"
        [ test "no conflicts -> Ok with empty soft conflicts" <|
            \_ ->
                let
                    slot =
                        VolunteerSlot.walkUp testScorer Preliminary1
                in
                VolunteerSlot.validateCheckIn slot testTrial [] []
                    |> Result.map Tuple.second
                    |> Expect.equal (Ok [])
        , test "no conflicts -> Ok slot is checked in" <|
            \_ ->
                let
                    slot =
                        VolunteerSlot.walkUp testScorer Preliminary1
                in
                VolunteerSlot.validateCheckIn slot testTrial [] []
                    |> Result.map (Tuple.first >> VolunteerSlot.isCheckedIn)
                    |> Expect.equal (Ok True)
        , test "hard conflict -> Err" <|
            \_ ->
                let
                    slot =
                        VolunteerSlot.walkUp testScorer Preliminary1

                    hardConflict =
                        Conflict.hardConflict testScorer (WithTeam teamA)
                in
                VolunteerSlot.validateCheckIn slot testTrial [ hardConflict ] []
                    |> Expect.err
        , test "soft conflict -> Ok with warnings" <|
            \_ ->
                let
                    slot =
                        VolunteerSlot.walkUp testScorer Preliminary1

                    history =
                        [ ( Preliminary2, teamA, teamC ) ]
                in
                VolunteerSlot.validateCheckIn slot testTrial [] history
                    |> Result.map (Tuple.second >> List.length)
                    |> Expect.equal (Ok 1)
        , test "both hard and soft -> Err (hard blocks)" <|
            \_ ->
                let
                    slot =
                        VolunteerSlot.walkUp testScorer Preliminary1

                    hardConflict =
                        Conflict.hardConflict testScorer (WithTeam teamA)

                    history =
                        [ ( Preliminary2, teamA, teamC ) ]
                in
                VolunteerSlot.validateCheckIn slot testTrial [ hardConflict ] history
                    |> Expect.err
        ]
