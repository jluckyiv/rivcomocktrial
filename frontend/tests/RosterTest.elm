module RosterTest exposing (suite)

import Expect
import Roster exposing (AttorneyDuty(..), RoleAssignment(..), Roster)
import Side exposing (Side(..))
import Student exposing (Student)
import Test exposing (Test, describe, test)
import TestHelpers
import Witness


suite : Test
suite =
    let
        alice =
            TestHelpers.alice

        bob =
            TestHelpers.bob

        charlie =
            TestHelpers.charlie

        diana =
            TestHelpers.diana

        eve =
            TestHelpers.eve

        frank =
            TestHelpers.frank

        grace =
            TestHelpers.grace

        henry =
            TestHelpers.henry

        iris =
            TestHelpers.iris

        w1 =
            TestHelpers.witness1

        w2 =
            TestHelpers.witness2

        w3 =
            TestHelpers.witness3

        w4 =
            TestHelpers.witness4

        validList =
            [ ClerkRole alice
            , BailiffRole bob
            , PretrialAttorney charlie
            , WitnessRole diana w1
            , WitnessRole eve w2
            , WitnessRole frank w3
            , WitnessRole grace w4
            , TrialAttorney henry Opening
            , TrialAttorney iris (DirectOf w1)
            ]
    in
    describe "Roster"
        [ describe "create"
            [ test "rejects empty list" <|
                \_ ->
                    Roster.create Prosecution []
                        |> isErr
                        |> Expect.equal True
            , test "accepts valid roster" <|
                \_ ->
                    Roster.create Prosecution validList
                        |> isOk
                        |> Expect.equal True
            , test "assignments accessor round-trips" <|
                \_ ->
                    Roster.create Prosecution validList
                        |> Result.map Roster.assignments
                        |> Expect.equal (Ok validList)
            ]
        , describe "composition validation"
            [ test "missing clerk rejected" <|
                \_ ->
                    validList
                        |> List.filter (not << isClerk)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "duplicate clerk rejected" <|
                \_ ->
                    (ClerkRole bob :: validList)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "missing bailiff rejected" <|
                \_ ->
                    validList
                        |> List.filter (not << isBailiff)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "missing pretrial attorney rejected" <|
                \_ ->
                    validList
                        |> List.filter (not << isPretrial)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "too few witnesses rejected (2)" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "too many witnesses rejected (5)" <|
                \_ ->
                    (WitnessRole henry w1 :: validList)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "3 witnesses rejected even when pretrial doubles" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole charlie w1
                    , WitnessRole diana w2
                    , WitnessRole eve w3
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "4 witnesses with pretrial doubling accepted" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole charlie w1
                    , WitnessRole diana w2
                    , WitnessRole eve w3
                    , WitnessRole frank w4
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isOk
                        |> Expect.equal True
            , test "0 trial attorneys rejected" <|
                \_ ->
                    validList
                        |> List.filter (not << isTrialAttorney)
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "4 trial attorneys rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    , TrialAttorney charlie (CrossOf w2)
                    , TrialAttorney diana Closing
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "1 trial attorney accepted" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isOk
                        |> Expect.equal True
            , test "3 trial attorneys accepted" <|
                \_ ->
                    let
                        jake =
                            Student.create
                                (TestHelpers.studentName "Jake" "Long")
                                Student.HeHim
                    in
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    , TrialAttorney jake Closing
                    ]
                        |> Roster.create Prosecution
                        |> isOk
                        |> Expect.equal True
            , test "duplicate student rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole alice
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "pretrial attorney as witness allowed" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole charlie w1
                    , WitnessRole diana w2
                    , WitnessRole eve w3
                    , WitnessRole frank w4
                    , TrialAttorney henry Opening
                    ]
                        |> Roster.create Prosecution
                        |> isOk
                        |> Expect.equal True
            , test "trial attorney as witness rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole henry w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "bailiff as witness rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole bob w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "clerk as witness rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole alice w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "same student in two witness roles rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole diana w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "pretrial attorney as trial attorney rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney charlie Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "pretrial attorney as clerk rejected" <|
                \_ ->
                    [ ClerkRole charlie
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "pretrial attorney as bailiff rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole charlie
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "same student as two trial attorneys rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney henry (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "trial attorney as clerk rejected" <|
                \_ ->
                    [ ClerkRole henry
                    , BailiffRole bob
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "trial attorney as bailiff rejected" <|
                \_ ->
                    [ ClerkRole alice
                    , BailiffRole henry
                    , PretrialAttorney charlie
                    , WitnessRole diana w1
                    , WitnessRole eve w2
                    , WitnessRole frank w3
                    , WitnessRole grace w4
                    , TrialAttorney henry Opening
                    , TrialAttorney iris (DirectOf w1)
                    ]
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "multiple errors accumulate" <|
                \_ ->
                    Roster.create Prosecution [ WitnessRole alice w1 ]
                        |> (\result ->
                                case result of
                                    Err errors ->
                                        List.length errors
                                            |> Expect.atLeast 2

                                    Ok _ ->
                                        Expect.fail "expected Err"
                           )
            ]
        , describe "student"
            [ test "returns student from PretrialAttorney" <|
                \_ ->
                    PretrialAttorney alice
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from TrialAttorney" <|
                \_ ->
                    TrialAttorney alice Opening
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from WitnessRole" <|
                \_ ->
                    WitnessRole alice w1
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from ClerkRole" <|
                \_ ->
                    ClerkRole alice
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from BailiffRole" <|
                \_ ->
                    BailiffRole alice
                        |> Roster.student
                        |> Expect.equal alice
            , test "returns student from UnofficialTimer" <|
                \_ ->
                    UnofficialTimer alice
                        |> Roster.student
                        |> Expect.equal alice
            ]
        , describe "AttorneyDuty"
            [ test "DirectOf carries a witness" <|
                \_ ->
                    DirectOf w1
                        |> (\duty ->
                                case duty of
                                    DirectOf w ->
                                        Witness.name w
                                            |> Expect.equal "Jordan Riley"

                                    _ ->
                                        Expect.fail "expected DirectOf"
                           )
            , test "CrossOf carries a witness" <|
                \_ ->
                    CrossOf w1
                        |> (\duty ->
                                case duty of
                                    CrossOf w ->
                                        Witness.name w
                                            |> Expect.equal "Jordan Riley"

                                    _ ->
                                        Expect.fail "expected CrossOf"
                           )
            ]
        , describe "side"
            [ test "side accessor returns Prosecution" <|
                \_ ->
                    Roster.create Prosecution validList
                        |> Result.map Roster.side
                        |> Expect.equal (Ok Prosecution)
            , test "side accessor returns Defense" <|
                \_ ->
                    Roster.create Defense validList
                        |> Result.map Roster.side
                        |> Expect.equal (Ok Defense)
            ]
        , describe "UnofficialTimer"
            [ test "defense roster with timer accepted" <|
                \_ ->
                    let
                        jake =
                            Student.create
                                (TestHelpers.studentName "Jake" "Long")
                                Student.HeHim
                    in
                    (validList ++ [ UnofficialTimer jake ])
                        |> Roster.create Defense
                        |> isOk
                        |> Expect.equal True
            , test "prosecution roster with timer rejected" <|
                \_ ->
                    let
                        jake =
                            Student.create
                                (TestHelpers.studentName "Jake" "Long")
                                Student.HeHim
                    in
                    (validList ++ [ UnofficialTimer jake ])
                        |> Roster.create Prosecution
                        |> isErr
                        |> Expect.equal True
            , test "defense roster without timer accepted" <|
                \_ ->
                    Roster.create Defense validList
                        |> isOk
                        |> Expect.equal True
            , test "duplicate timer student rejected" <|
                \_ ->
                    (validList ++ [ UnofficialTimer alice ])
                        |> Roster.create Defense
                        |> isErr
                        |> Expect.equal True
            , test "two timers rejected" <|
                \_ ->
                    let
                        jake =
                            Student.create
                                (TestHelpers.studentName "Jake" "Long")
                                Student.HeHim

                        kim =
                            Student.create
                                (TestHelpers.studentName "Kim" "Lee")
                                Student.SheHer
                    in
                    (validList ++ [ UnofficialTimer jake, UnofficialTimer kim ])
                        |> Roster.create Defense
                        |> isErr
                        |> Expect.equal True
            ]
        ]


isClerk : RoleAssignment -> Bool
isClerk assignment =
    case assignment of
        ClerkRole _ ->
            True

        _ ->
            False


isBailiff : RoleAssignment -> Bool
isBailiff assignment =
    case assignment of
        BailiffRole _ ->
            True

        _ ->
            False


isPretrial : RoleAssignment -> Bool
isPretrial assignment =
    case assignment of
        PretrialAttorney _ ->
            True

        _ ->
            False


isTrialAttorney : RoleAssignment -> Bool
isTrialAttorney assignment =
    case assignment of
        TrialAttorney _ _ ->
            True

        _ ->
            False


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
