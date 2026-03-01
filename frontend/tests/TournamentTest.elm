module TournamentTest exposing (suite)

import Error exposing (Error(..))
import Expect
import Test exposing (Test, describe, test)
import Tournament


suite : Test
suite =
    describe "Tournament"
        [ nameFromStringSuite
        , yearFromIntSuite
        , configFromIntsSuite
        , createSuite
        , stateMachineSuite
        , statusToStringSuite
        ]


unsafeName : String -> Tournament.Name
unsafeName raw =
    case Tournament.nameFromString raw of
        Ok n ->
            n

        Err _ ->
            Debug.todo ("Invalid tournament name: " ++ raw)


unsafeYear : Int -> Tournament.Year
unsafeYear n =
    case Tournament.yearFromInt n of
        Ok y ->
            y

        Err _ ->
            Debug.todo ("Invalid year: " ++ String.fromInt n)


unsafeConfig : Int -> Int -> Tournament.Config
unsafeConfig p e =
    case Tournament.configFromInts p e of
        Ok c ->
            c

        Err _ ->
            Debug.todo "Invalid config"


draftTournament : Tournament.Tournament
draftTournament =
    Tournament.create (unsafeName "RCMT") (unsafeYear 2026) (unsafeConfig 4 3)


nameFromStringSuite : Test
nameFromStringSuite =
    describe "nameFromString"
        [ test "accepts a valid name" <|
            \_ ->
                Tournament.nameFromString "RCMT 2026"
                    |> isOk
                    |> Expect.equal True
        , test "round-trips through nameToString" <|
            \_ ->
                Tournament.nameFromString "RCMT 2026"
                    |> Result.map Tournament.nameToString
                    |> Expect.equal (Ok "RCMT 2026")
        , test "trims whitespace" <|
            \_ ->
                Tournament.nameFromString "  RCMT 2026  "
                    |> Result.map Tournament.nameToString
                    |> Expect.equal (Ok "RCMT 2026")
        , test "rejects blank string" <|
            \_ ->
                Tournament.nameFromString ""
                    |> isErr
                    |> Expect.equal True
        , test "rejects whitespace-only string" <|
            \_ ->
                Tournament.nameFromString "   "
                    |> isErr
                    |> Expect.equal True
        ]


yearFromIntSuite : Test
yearFromIntSuite =
    describe "yearFromInt"
        [ test "accepts 2026" <|
            \_ ->
                Tournament.yearFromInt 2026
                    |> Result.map Tournament.yearToInt
                    |> Expect.equal (Ok 2026)
        , test "accepts 2000 (lower bound)" <|
            \_ ->
                Tournament.yearFromInt 2000
                    |> isOk
                    |> Expect.equal True
        , test "accepts 2100 (upper bound)" <|
            \_ ->
                Tournament.yearFromInt 2100
                    |> isOk
                    |> Expect.equal True
        , test "rejects 1999" <|
            \_ ->
                Tournament.yearFromInt 1999
                    |> isErr
                    |> Expect.equal True
        , test "rejects 2101" <|
            \_ ->
                Tournament.yearFromInt 2101
                    |> isErr
                    |> Expect.equal True
        ]


configFromIntsSuite : Test
configFromIntsSuite =
    describe "configFromInts"
        [ test "accepts valid rounds" <|
            \_ ->
                Tournament.configFromInts 4 3
                    |> isOk
                    |> Expect.equal True
        , test "prelimRounds accessor" <|
            \_ ->
                Tournament.configFromInts 4 3
                    |> Result.map Tournament.prelimRounds
                    |> Expect.equal (Ok 4)
        , test "elimRounds accessor" <|
            \_ ->
                Tournament.configFromInts 4 3
                    |> Result.map Tournament.elimRounds
                    |> Expect.equal (Ok 3)
        , test "rejects zero preliminary rounds" <|
            \_ ->
                Tournament.configFromInts 0 3
                    |> isErr
                    |> Expect.equal True
        , test "rejects negative preliminary rounds" <|
            \_ ->
                Tournament.configFromInts -1 3
                    |> isErr
                    |> Expect.equal True
        , test "rejects zero elimination rounds" <|
            \_ ->
                Tournament.configFromInts 4 0
                    |> isErr
                    |> Expect.equal True
        , test "accumulates errors for both invalid" <|
            \_ ->
                case Tournament.configFromInts 0 0 of
                    Err errors ->
                        List.length errors
                            |> Expect.equal 2

                    Ok _ ->
                        Expect.fail "Should have failed"
        ]


createSuite : Test
createSuite =
    describe "create"
        [ test "starts as Draft" <|
            \_ ->
                draftTournament
                    |> Tournament.status
                    |> Tournament.statusToString
                    |> Expect.equal "Draft"
        , test "accessor round-trips name" <|
            \_ ->
                draftTournament
                    |> Tournament.tournamentName
                    |> Tournament.nameToString
                    |> Expect.equal "RCMT"
        , test "accessor round-trips year" <|
            \_ ->
                draftTournament
                    |> Tournament.year
                    |> Tournament.yearToInt
                    |> Expect.equal 2026
        , test "accessor round-trips config prelim rounds" <|
            \_ ->
                draftTournament
                    |> Tournament.config
                    |> Tournament.prelimRounds
                    |> Expect.equal 4
        , test "accessor round-trips config elim rounds" <|
            \_ ->
                draftTournament
                    |> Tournament.config
                    |> Tournament.elimRounds
                    |> Expect.equal 3
        ]


stateMachineSuite : Test
stateMachineSuite =
    describe "state machine"
        [ test "Draft -> Registration succeeds" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Registration")
        , test "Registration -> Active succeeds" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Active")
        , test "Active -> Completed succeeds" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.andThen Tournament.complete
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Completed")
        , test "Draft -> Active fails" <|
            \_ ->
                draftTournament
                    |> Tournament.activate
                    |> isErr
                    |> Expect.equal True
        , test "Draft -> Completed fails" <|
            \_ ->
                draftTournament
                    |> Tournament.complete
                    |> isErr
                    |> Expect.equal True
        , test "Registration -> Completed fails" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.complete
                    |> isErr
                    |> Expect.equal True
        , test "Completed -> Draft fails (no reverse)" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.andThen Tournament.complete
                    |> Result.andThen Tournament.openRegistration
                    |> isErr
                    |> Expect.equal True
        , test "Active -> Registration fails (no reverse)" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.andThen Tournament.openRegistration
                    |> isErr
                    |> Expect.equal True
        ]


statusToStringSuite : Test
statusToStringSuite =
    describe "statusToString"
        [ test "Draft via accessor" <|
            \_ ->
                draftTournament
                    |> Tournament.status
                    |> Tournament.statusToString
                    |> Expect.equal "Draft"
        , test "Registration via accessor" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Registration")
        , test "Active via accessor" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Active")
        , test "Completed via accessor" <|
            \_ ->
                draftTournament
                    |> Tournament.openRegistration
                    |> Result.andThen Tournament.activate
                    |> Result.andThen Tournament.complete
                    |> Result.map (Tournament.status >> Tournament.statusToString)
                    |> Expect.equal (Ok "Completed")
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
