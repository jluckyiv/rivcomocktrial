module Tournament exposing
    ( Config
    , Name
    , Status
    , Tournament
    , Year
    , activate
    , complete
    , config
    , configFromInts
    , create
    , elimRounds
    , nameFromString
    , nameToString
    , openRegistration
    , prelimRounds
    , status
    , statusToString
    , tournamentName
    , year
    , yearFromInt
    , yearToInt
    )

import Error exposing (Error(..))
import Validate


type Name
    = Name String


nameFromString : String -> Result (List Error) Name
nameFromString raw =
    let
        trimmed =
            String.trim raw
    in
    Validate.validate
        (Validate.all
            [ Validate.ifBlank identity
                (Error "Tournament name cannot be blank")
            ]
        )
        trimmed
        |> Result.map (\_ -> Name trimmed)


nameToString : Name -> String
nameToString (Name s) =
    s


type Year
    = Year Int


yearFromInt : Int -> Result (List Error) Year
yearFromInt n =
    if n >= 2000 && n <= 2100 then
        Ok (Year n)

    else
        Err [ Error ("Year must be between 2000 and 2100, got " ++ String.fromInt n) ]


yearToInt : Year -> Int
yearToInt (Year n) =
    n


type Config
    = Config
        { numPreliminaryRounds : Int
        , numEliminationRounds : Int
        }


configFromInts : Int -> Int -> Result (List Error) Config
configFromInts prelim elim =
    let
        prelimError =
            if prelim >= 1 then
                []

            else
                [ Error ("Preliminary rounds must be positive, got " ++ String.fromInt prelim) ]

        elimError =
            if elim >= 1 then
                []

            else
                [ Error ("Elimination rounds must be positive, got " ++ String.fromInt elim) ]

        errors =
            prelimError ++ elimError
    in
    if List.isEmpty errors then
        Ok (Config { numPreliminaryRounds = prelim, numEliminationRounds = elim })

    else
        Err errors


prelimRounds : Config -> Int
prelimRounds (Config r) =
    r.numPreliminaryRounds


elimRounds : Config -> Int
elimRounds (Config r) =
    r.numEliminationRounds


type Status
    = Draft
    | Registration
    | Active
    | Completed


type Tournament
    = Tournament
        { name : Name
        , year : Year
        , config : Config
        , status : Status
        }


create : Name -> Year -> Config -> Tournament
create n y c =
    Tournament
        { name = n
        , year = y
        , config = c
        , status = Draft
        }


tournamentName : Tournament -> Name
tournamentName (Tournament r) =
    r.name


year : Tournament -> Year
year (Tournament r) =
    r.year


config : Tournament -> Config
config (Tournament r) =
    r.config


status : Tournament -> Status
status (Tournament r) =
    r.status


openRegistration : Tournament -> Result (List Error) Tournament
openRegistration (Tournament r) =
    case r.status of
        Draft ->
            Ok (Tournament { r | status = Registration })

        other ->
            Err [ Error ("Cannot open registration from " ++ statusToString other ++ " status") ]


activate : Tournament -> Result (List Error) Tournament
activate (Tournament r) =
    case r.status of
        Registration ->
            Ok (Tournament { r | status = Active })

        other ->
            Err [ Error ("Cannot activate from " ++ statusToString other ++ " status") ]


complete : Tournament -> Result (List Error) Tournament
complete (Tournament r) =
    case r.status of
        Active ->
            Ok (Tournament { r | status = Completed })

        other ->
            Err [ Error ("Cannot complete from " ++ statusToString other ++ " status") ]


statusToString : Status -> String
statusToString s =
    case s of
        Draft ->
            "Draft"

        Registration ->
            "Registration"

        Active ->
            "Active"

        Completed ->
            "Completed"
