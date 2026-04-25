module Pages.Admin.Pairings exposing (Model, Msg, page)

import Api exposing (Courtroom, Round, Team, Trial)
import Auth
import Coach
import Dict
import District
import Effect exposing (Effect)
import Email
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import MatchHistory exposing (MatchHistory)
import Page exposing (Page)
import Pb
import PowerMatch
    exposing
        ( CrossBracketStrategy(..)
        , PowerMatchResult
        , RankedTeam
        )
import Route exposing (Route)
import School
import Shared
import Team as DomainTeam
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ _ route =
    Page.new
        { init = init route
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type InputMode
    = DropdownMode
    | BulkTextMode


type alias BulkParsedPairing =
    { prosecutionTeamNumber : Int
    , defenseTeamNumber : Int
    , courtroomName : String
    }


type FormContext
    = Creating
    | Editing String


type alias TrialForm =
    { prosecution : String
    , defense : String
    , courtroom : String
    }


type FormState
    = FormOpen FormContext TrialForm (List String)
    | FormSaving FormContext TrialForm


type BulkState
    = BulkIdle
    | BulkEditing String
    | BulkPreview String (List BulkParsedPairing)
    | BulkSaving String (List BulkParsedPairing)
    | BulkFailed String (List String)


type alias Model =
    { roundId : String
    , round : Maybe Round
    , trials : List Trial
    , teams : List Team
    , courtrooms : List Courtroom
    , allTrials : List Trial
    , loading : Bool
    , errors : List String
    , inputMode : InputMode
    , form : FormState
    , deleting : Maybe String
    , bulk : BulkState
    , crossBracketStrategy : CrossBracketStrategy
    , powerMatchResult : Maybe PowerMatchResult
    }


emptyForm : TrialForm
emptyForm =
    { prosecution = "", defense = "", courtroom = "" }


init : Route () -> () -> ( Model, Effect Msg )
init route _ =
    let
        roundId =
            Dict.get "round" route.query |> Maybe.withDefault ""
    in
    ( { roundId = roundId
      , round = Nothing
      , trials = []
      , teams = []
      , courtrooms = []
      , allTrials = []
      , loading = True
      , errors = []
      , inputMode = DropdownMode
      , form = FormOpen Creating emptyForm []
      , deleting = Nothing
      , bulk = BulkIdle
      , crossBracketStrategy = HighHigh
      , powerMatchResult = Nothing
      }
    , if roundId == "" then
        Effect.none

      else
        Effect.batch
            [ Pb.adminList
                { collection = "trials"
                , tag = "trials"
                , filter = "round='" ++ roundId ++ "'"
                , sort = ""
                }
            , Pb.adminList
                { collection = "trials"
                , tag = "all-trials"
                , filter = ""
                , sort = ""
                }
            , Pb.adminList
                { collection = "rounds"
                , tag = "rounds"
                , filter = ""
                , sort = ""
                }
            , Pb.adminList
                { collection = "courtrooms"
                , tag = "courtrooms"
                , filter = ""
                , sort = ""
                }
            ]
    )



-- UPDATE


type Msg
    = SwitchMode InputMode
    | FormProsecutionChanged String
    | FormDefenseChanged String
    | FormCourtroomChanged String
    | SaveTrial
    | EditTrial Trial
    | CancelEdit
    | DeleteTrial String
    | BulkTextChanged String
    | ParseBulkText
    | ConfirmBulkCreate
    | CancelBulkPreview
    | SetCrossBracketStrategy CrossBracketStrategy
    | GeneratePowerMatch
    | AcceptPowerMatch
    | ClearPowerMatch
    | PbMsg Json.Decode.Value


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        SwitchMode mode ->
            ( { model | inputMode = mode }, Effect.none )

        FormProsecutionChanged val ->
            ( { model | form = updateFormField (\f -> { f | prosecution = val }) model.form }
            , Effect.none
            )

        FormDefenseChanged val ->
            ( { model | form = updateFormField (\f -> { f | defense = val }) model.form }
            , Effect.none
            )

        FormCourtroomChanged val ->
            ( { model | form = updateFormField (\f -> { f | courtroom = val }) model.form }
            , Effect.none
            )

        SaveTrial ->
            case model.form of
                FormOpen ctx f _ ->
                    case validateTrialForm f of
                        Err errors ->
                            ( { model | form = FormOpen ctx f errors }, Effect.none )

                        Ok _ ->
                            ( { model | form = FormSaving ctx f }
                            , case ctx of
                                Editing id ->
                                    Pb.adminUpdate
                                        { collection = "trials"
                                        , id = id
                                        , tag = "save-trial"
                                        , body =
                                            Api.encodeTrial
                                                { round = model.roundId
                                                , prosecutionTeam = f.prosecution
                                                , defenseTeam = f.defense
                                                , courtroom = f.courtroom
                                                }
                                        }

                                Creating ->
                                    Pb.adminCreate
                                        { collection = "trials"
                                        , tag = "save-trial"
                                        , body =
                                            Api.encodeTrial
                                                { round = model.roundId
                                                , prosecutionTeam = f.prosecution
                                                , defenseTeam = f.defense
                                                , courtroom = f.courtroom
                                                }
                                        }
                            )

                FormSaving _ _ ->
                    ( model, Effect.none )

        EditTrial trial ->
            ( { model
                | form =
                    FormOpen (Editing trial.id)
                        { prosecution = trial.prosecutionTeam
                        , defense = trial.defenseTeam
                        , courtroom = trial.courtroom
                        }
                        []
              }
            , Effect.none
            )

        CancelEdit ->
            ( { model | form = FormOpen Creating emptyForm [] }, Effect.none )

        DeleteTrial id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete
                { collection = "trials"
                , id = id
                , tag = "delete-trial"
                }
            )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        ParseBulkText ->
            let
                text =
                    bulkStateText model.bulk

                parsed =
                    parseBulkInput text

                errors =
                    validateBulkParsed model.teams parsed
            in
            case errors of
                [] ->
                    ( { model | bulk = BulkPreview text parsed }, Effect.none )

                _ ->
                    ( { model | bulk = BulkFailed text errors }, Effect.none )

        ConfirmBulkCreate ->
            case model.bulk of
                BulkPreview text parsed ->
                    let
                        cmds =
                            List.filterMap
                                (\p ->
                                    let
                                        pTeam =
                                            findTeamByNumber model.teams p.prosecutionTeamNumber

                                        dTeam =
                                            findTeamByNumber model.teams p.defenseTeamNumber

                                        courtroom =
                                            findCourtroomByName model.courtrooms p.courtroomName
                                    in
                                    case ( pTeam, dTeam ) of
                                        ( Just pt, Just dt ) ->
                                            Just
                                                (Pb.adminCreate
                                                    { collection = "trials"
                                                    , tag = "bulk-trial"
                                                    , body =
                                                        Api.encodeTrial
                                                            { round = model.roundId
                                                            , prosecutionTeam = pt.id
                                                            , defenseTeam = dt.id
                                                            , courtroom = courtroom |> Maybe.map .id |> Maybe.withDefault ""
                                                            }
                                                    }
                                                )

                                        _ ->
                                            Nothing
                                )
                                parsed
                    in
                    ( { model | bulk = BulkSaving text parsed }
                    , Effect.batch cmds
                    )

                _ ->
                    ( model, Effect.none )

        CancelBulkPreview ->
            ( { model | bulk = BulkEditing (bulkStateText model.bulk) }, Effect.none )

        SetCrossBracketStrategy strategy ->
            ( { model | crossBracketStrategy = strategy }, Effect.none )

        GeneratePowerMatch ->
            let
                allHistory =
                    buildMatchHistory model.teams model.allTrials

                currentRoundHistory =
                    buildMatchHistory model.teams model.trials

                rankedTeams =
                    buildRankedTeams model.teams

                result =
                    PowerMatch.powerMatch
                        model.crossBracketStrategy
                        rankedTeams
                        allHistory
                        currentRoundHistory
            in
            ( { model | powerMatchResult = Just result }
            , Effect.none
            )

        AcceptPowerMatch ->
            case model.powerMatchResult of
                Nothing ->
                    ( model, Effect.none )

                Just result ->
                    let
                        cmds =
                            List.filterMap
                                (\p ->
                                    case ( apiIdForDomainTeam model.teams p.prosecutionTeam, apiIdForDomainTeam model.teams p.defenseTeam ) of
                                        ( Just pId, Just dId ) ->
                                            Just
                                                (Pb.adminCreate
                                                    { collection = "trials"
                                                    , tag = "save-trial"
                                                    , body =
                                                        Api.encodeTrial
                                                            { round = model.roundId
                                                            , prosecutionTeam = pId
                                                            , defenseTeam = dId
                                                            , courtroom = ""
                                                            }
                                                    }
                                                )

                                        _ ->
                                            Nothing
                                )
                                result.pairings
                    in
                    ( { model | powerMatchResult = Nothing }
                    , Effect.batch cmds
                    )

        ClearPowerMatch ->
            ( { model | powerMatchResult = Nothing }, Effect.none )

        PbMsg value ->
            case Pb.responseTag value of
                Just "trials" ->
                    case Pb.decodeList Api.trialDecoder value of
                        Ok trials ->
                            ( { model | trials = trials, loading = False }, Effect.none )

                        Err _ ->
                            ( { model | loading = False, errors = [ "Failed to load trials." ] }, Effect.none )

                Just "all-trials" ->
                    case Pb.decodeList Api.trialDecoder value of
                        Ok trials ->
                            ( { model | allTrials = trials }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "rounds" ->
                    case Pb.decodeList Api.roundDecoder value of
                        Ok rounds ->
                            let
                                round =
                                    List.filter (\r -> r.id == model.roundId) rounds
                                        |> List.head

                                tournamentId =
                                    round |> Maybe.map .tournament |> Maybe.withDefault ""
                            in
                            ( { model | round = round }
                            , if tournamentId /= "" then
                                Pb.adminList
                                    { collection = "teams"
                                    , tag = "teams"
                                    , filter = ""
                                    , sort = ""
                                    }

                              else
                                Effect.none
                            )

                        Err _ ->
                            ( { model | errors = [ "Failed to load rounds." ] }, Effect.none )

                Just "teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok teams ->
                            let
                                tournamentId =
                                    model.round |> Maybe.map .tournament |> Maybe.withDefault ""

                                filtered =
                                    List.filter (\t -> t.tournament == tournamentId) teams
                            in
                            ( { model | teams = filtered }, Effect.none )

                        Err _ ->
                            ( { model | errors = [ "Failed to load teams." ] }, Effect.none )

                Just "courtrooms" ->
                    case Pb.decodeList Api.courtroomDecoder value of
                        Ok courtrooms ->
                            ( { model | courtrooms = courtrooms }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-trial" ->
                    case Pb.decodeRecord Api.trialDecoder value of
                        Ok trial ->
                            case model.form of
                                FormSaving ctx _ ->
                                    let
                                        updatedTrials =
                                            case ctx of
                                                Editing _ ->
                                                    List.map
                                                        (\t ->
                                                            if t.id == trial.id then
                                                                trial

                                                            else
                                                                t
                                                        )
                                                        model.trials

                                                Creating ->
                                                    model.trials ++ [ trial ]

                                        updatedAll =
                                            case ctx of
                                                Editing _ ->
                                                    List.map
                                                        (\t ->
                                                            if t.id == trial.id then
                                                                trial

                                                            else
                                                                t
                                                        )
                                                        model.allTrials

                                                Creating ->
                                                    model.allTrials ++ [ trial ]
                                    in
                                    ( { model
                                        | trials = updatedTrials
                                        , allTrials = updatedAll
                                        , form = FormOpen Creating emptyForm []
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                        Err _ ->
                            case model.form of
                                FormSaving ctx f ->
                                    ( { model | form = FormOpen ctx f [ "Failed to save trial." ] }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-trial" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | trials = List.filter (\t -> t.id /= id) model.trials
                                , allTrials = List.filter (\t -> t.id /= id) model.allTrials
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                Just "bulk-trial" ->
                    case Pb.decodeRecord Api.trialDecoder value of
                        Ok trial ->
                            ( { model
                                | trials = model.trials ++ [ trial ]
                                , allTrials = model.allTrials ++ [ trial ]
                                , bulk = BulkIdle
                              }
                            , Effect.none
                            )

                        Err _ ->
                            case model.bulk of
                                BulkSaving text _ ->
                                    ( { model | bulk = BulkFailed text [ "Failed to create some trials." ] }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                _ ->
                    ( model, Effect.none )



-- FORM HELPERS


updateFormField : (TrialForm -> TrialForm) -> FormState -> FormState
updateFormField fn form =
    case form of
        FormOpen ctx f _ ->
            FormOpen ctx (fn f) []

        FormSaving _ _ ->
            form


formContext : FormState -> FormContext
formContext form =
    case form of
        FormOpen ctx _ _ ->
            ctx

        FormSaving ctx _ ->
            ctx


formData : FormState -> TrialForm
formData form =
    case form of
        FormOpen _ f _ ->
            f

        FormSaving _ f ->
            f


formErrors : FormState -> List String
formErrors form =
    case form of
        FormOpen _ _ errors ->
            errors

        FormSaving _ _ ->
            []


isSaving : FormState -> Bool
isSaving form =
    case form of
        FormSaving _ _ ->
            True

        FormOpen _ _ _ ->
            False


bulkStateText : BulkState -> String
bulkStateText bulk =
    case bulk of
        BulkIdle ->
            ""

        BulkEditing text ->
            text

        BulkPreview text _ ->
            text

        BulkSaving text _ ->
            text

        BulkFailed text _ ->
            text



-- VALIDATION


validateTrialForm : TrialForm -> Result (List String) TrialForm
validateTrialForm f =
    let
        errors =
            []
                |> addErrorIf (String.trim f.prosecution == "") "Prosecution team is required"
                |> addErrorIf (String.trim f.defense == "") "Defense team is required"
                |> addErrorIf
                    (f.prosecution /= "" && f.prosecution == f.defense)
                    "Prosecution and defense cannot be the same team"
    in
    if List.isEmpty errors then
        Ok f

    else
        Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors



-- DOMAIN CONVERSION HELPERS


toDomainTeam : Team -> Maybe DomainTeam.Team
toDomainTeam apiTeam =
    Maybe.map2
        (\num name ->
            Maybe.map2
                (\s c -> DomainTeam.create num name s c)
                placeholderSchool
                placeholderCoach
        )
        (DomainTeam.numberFromInt apiTeam.teamNumber |> Result.toMaybe)
        (DomainTeam.nameFromString apiTeam.name |> Result.toMaybe)
        |> Maybe.andThen identity


placeholderSchool : Maybe School.School
placeholderSchool =
    case ( School.nameFromString "Placeholder", District.nameFromString "Placeholder" ) of
        ( Ok sn, Ok dn ) ->
            Just (School.create sn (District.create dn))

        _ ->
            Nothing


placeholderCoach : Maybe Coach.TeacherCoach
placeholderCoach =
    case ( Coach.nameFromStrings "Placeholder" "Coach", Email.fromString "placeholder@example.com" ) of
        ( Ok cn, Ok em ) ->
            Just (Coach.verify (Coach.apply cn em))

        _ ->
            Nothing


buildMatchHistory : List Team -> List Trial -> MatchHistory
buildMatchHistory teams trials =
    let
        findDomainTeam teamId =
            List.filter (\t -> t.id == teamId) teams
                |> List.head
                |> Maybe.andThen toDomainTeam

        records =
            List.filterMap
                (\trial ->
                    case ( findDomainTeam trial.prosecutionTeam, findDomainTeam trial.defenseTeam ) of
                        ( Just p, Just d ) ->
                            Just { prosecution = p, defense = d }

                        _ ->
                            Nothing
                )
                trials
    in
    MatchHistory.fromRecords records


buildRankedTeams : List Team -> List RankedTeam
buildRankedTeams teams =
    List.filterMap
        (\apiTeam ->
            toDomainTeam apiTeam
                |> Maybe.map
                    (\domainTeam ->
                        -- Without score data from API, treat all teams
                        -- as 0-0. Round 1 random pairing works correctly;
                        -- later rounds need score data to rank properly.
                        { team = domainTeam
                        , wins = 0
                        , losses = 0
                        , rank = apiTeam.teamNumber
                        }
                    )
        )
        teams


apiIdForDomainTeam : List Team -> DomainTeam.Team -> Maybe String
apiIdForDomainTeam teams domainTeam =
    let
        num =
            DomainTeam.numberToInt (DomainTeam.teamNumber domainTeam)
    in
    List.filter (\t -> t.teamNumber == num) teams
        |> List.head
        |> Maybe.map .id


toDomainTeamFromId : List Team -> String -> Maybe DomainTeam.Team
toDomainTeamFromId teams teamId =
    List.filter (\t -> t.id == teamId) teams
        |> List.head
        |> Maybe.andThen toDomainTeam


proposedPairingLabel : DomainTeam.Team -> String
proposedPairingLabel team =
    String.fromInt (DomainTeam.numberToInt (DomainTeam.teamNumber team))
        ++ " - "
        ++ DomainTeam.nameToString (DomainTeam.teamName team)



-- BULK TEXT PARSING


parseBulkInput : String -> List BulkParsedPairing
parseBulkInput input =
    String.lines input
        |> List.filterMap parseBulkLine


parseBulkLine : String -> Maybe BulkParsedPairing
parseBulkLine line =
    let
        trimmed =
            String.trim line
    in
    if trimmed == "" then
        Nothing

    else
        let
            -- Format: {number} v {number} [{courtroom}]
            ( mainPart, courtroomPart ) =
                case String.split "[" trimmed of
                    [ main, rest ] ->
                        ( String.trim main
                        , String.replace "]" "" rest |> String.trim
                        )

                    _ ->
                        ( trimmed, "" )

            parts =
                String.split " v " mainPart
                    |> List.map String.trim
        in
        case parts of
            [ pStr, dStr ] ->
                case ( String.toInt pStr, String.toInt dStr ) of
                    ( Just p, Just d ) ->
                        Just { prosecutionTeamNumber = p, defenseTeamNumber = d, courtroomName = courtroomPart }

                    _ ->
                        Nothing

            _ ->
                Nothing


validateBulkParsed : List Team -> List BulkParsedPairing -> List String
validateBulkParsed teams parsed =
    List.concatMap
        (\p ->
            let
                pTeam =
                    findTeamByNumber teams p.prosecutionTeamNumber

                dTeam =
                    findTeamByNumber teams p.defenseTeamNumber
            in
            (case pTeam of
                Nothing ->
                    [ "Team #" ++ String.fromInt p.prosecutionTeamNumber ++ " not found" ]

                Just _ ->
                    []
            )
                ++ (case dTeam of
                        Nothing ->
                            [ "Team #" ++ String.fromInt p.defenseTeamNumber ++ " not found" ]

                        Just _ ->
                            []
                   )
        )
        parsed


findTeamByNumber : List Team -> Int -> Maybe Team
findTeamByNumber teams num =
    List.filter (\t -> t.teamNumber == num) teams |> List.head


findCourtroomByName : List Courtroom -> String -> Maybe Courtroom
findCourtroomByName courtrooms name =
    if name == "" then
        Nothing

    else
        List.filter (\c -> String.toLower c.name == String.toLower name) courtrooms |> List.head



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Pairings"
    , body =
        if model.roundId == "" then
            [ UI.alert { variant = "warning" }
                [ text "No round selected. "
                , a [ Attr.href "/admin/rounds" ] [ text "Go to Rounds" ]
                , text " and click \"Pairings\" on a round."
                ]
            ]

        else
            [ viewHeader model
            , UI.errorList model.errors
            , viewModeToggle model
            , case model.inputMode of
                DropdownMode ->
                    div []
                        [ viewDropdownForm model
                        , viewPowerMatchSection model
                        ]

                BulkTextMode ->
                    viewBulkTextSection model
            , if model.loading then
                UI.loading

              else
                viewTrialsTable model
            ]
    }


viewHeader : Model -> Html Msg
viewHeader model =
    let
        roundLabel =
            case model.round of
                Just r ->
                    "Round " ++ String.fromInt r.number ++ " (" ++ capitalize (Api.roundTypeToString r.roundType) ++ ")"

                Nothing ->
                    "Pairings"
    in
    UI.backLinkTitleBar
        { title = roundLabel
        , backLabel = "Back to Rounds"
        , backHref = "/admin/rounds"
        }


viewModeToggle : Model -> Html Msg
viewModeToggle model =
    UI.tabs
        [ { label = "Dropdown"
          , active = model.inputMode == DropdownMode
          , msg = SwitchMode DropdownMode
          }
        , { label = "Bulk Text"
          , active = model.inputMode == BulkTextMode
          , msg = SwitchMode BulkTextMode
          }
        ]


viewDropdownForm : Model -> Html Msg
viewDropdownForm model =
    let
        ctx =
            formContext model.form

        f =
            formData model.form

        saving =
            isSaving model.form

        editingId =
            case ctx of
                Editing id ->
                    Just id

                Creating ->
                    Nothing

        -- Teams already paired in this round (excluding the trial being edited)
        pairedTeamIds =
            model.trials
                |> List.filter (\t -> Just t.id /= editingId)
                |> List.concatMap (\t -> [ t.prosecutionTeam, t.defenseTeam ])

        -- Available teams: not yet paired, plus the currently selected values
        availableForProsecution =
            model.teams
                |> List.filter
                    (\t ->
                        t.id
                            == f.prosecution
                            || not (List.member t.id pairedTeamIds)
                    )
                |> List.filter (\t -> t.id /= f.defense || t.id == "")

        availableForDefense =
            model.teams
                |> List.filter
                    (\t ->
                        t.id
                            == f.defense
                            || not (List.member t.id pairedTeamIds)
                    )
                |> List.filter (\t -> t.id /= f.prosecution || t.id == "")

        -- Courtrooms already assigned in this round (excluding the trial being edited)
        usedCourtroomIds =
            model.trials
                |> List.filter (\t -> Just t.id /= editingId)
                |> List.map .courtroom
                |> List.filter (\id -> id /= "")

        availableCourtrooms =
            model.courtrooms
                |> List.filter
                    (\c ->
                        c.id
                            == f.courtroom
                            || not (List.member c.id usedCourtroomIds)
                    )
    in
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case ctx of
                    Editing _ ->
                        "Edit Trial"

                    Creating ->
                        "Add Trial"
                )
            , UI.errorList (formErrors model.form)
            , Html.form [ Events.onSubmit SaveTrial ]
                [ UI.formColumns
                    [ UI.selectField
                        { label = "Prosecution"
                        , value = f.prosecution
                        , onInput = FormProsecutionChanged
                        , options =
                            { value = "", label = "Select team..." }
                                :: List.map (\t -> { value = t.id, label = String.fromInt t.teamNumber ++ " - " ++ t.name }) availableForProsecution
                        }
                    , UI.selectField
                        { label = "Defense"
                        , value = f.defense
                        , onInput = FormDefenseChanged
                        , options =
                            { value = "", label = "Select team..." }
                                :: List.map (\t -> { value = t.id, label = String.fromInt t.teamNumber ++ " - " ++ t.name }) availableForDefense
                        }
                    , UI.selectField
                        { label = "Courtroom"
                        , value = f.courtroom
                        , onInput = FormCourtroomChanged
                        , options =
                            { value = "", label = "None" }
                                :: List.map (\c -> { value = c.id, label = c.name }) availableCourtrooms
                        }
                    ]
                , UI.actionRow
                    [ UI.primaryButton { label = "Save", loading = saving }
                    , case ctx of
                        Editing _ ->
                            UI.cancelButton CancelEdit

                        Creating ->
                            UI.empty
                    ]
                ]
            ]
        ]


viewPowerMatchSection : Model -> Html Msg
viewPowerMatchSection model =
    let
        roundNumber =
            model.round |> Maybe.map .number |> Maybe.withDefault 1
    in
    section [ Attr.class "mb-6" ]
        ([ UI.buttonRow
            [ if roundNumber >= 2 then
                UI.buttonRow
                    [ UI.actionButton { label = "Generate Power Match", variant = "info", msg = GeneratePowerMatch }
                    , select
                        [ Attr.class "select select-bordered select-sm"
                        , Events.onInput
                            (\val ->
                                if val == "HighLow" then
                                    SetCrossBracketStrategy HighLow

                                else
                                    SetCrossBracketStrategy HighHigh
                            )
                        ]
                        [ option
                            [ Attr.value "HighHigh"
                            , Attr.selected (model.crossBracketStrategy == HighHigh)
                            ]
                            [ text "High-High" ]
                        , option
                            [ Attr.value "HighLow"
                            , Attr.selected (model.crossBracketStrategy == HighLow)
                            ]
                            [ text "High-Low" ]
                        ]
                    , UI.hint "Cross-bracket strategy"
                    ]

              else
                UI.actionButton { label = "Generate Random Pairing", variant = "info", msg = GeneratePowerMatch }
            ]
         ]
            ++ (case model.powerMatchResult of
                    Just result ->
                        [ UI.card
                            [ UI.cardBody
                                ([ UI.cardTitle "Proposed Pairings" ]
                                    ++ List.map
                                        (\w -> UI.alert { variant = "warning" } [ text w ])
                                        result.warnings
                                    ++ [ UI.dataTable
                                            { columns = [ "Prosecution", "Defense" ]
                                            , rows = result.pairings
                                            , rowView =
                                                \p ->
                                                    tr []
                                                        [ td [] [ text (proposedPairingLabel p.prosecutionTeam) ]
                                                        , td [] [ text (proposedPairingLabel p.defenseTeam) ]
                                                        ]
                                            }
                                       , UI.actionRow
                                            [ UI.actionButton { label = "Accept & Create", variant = "success", msg = AcceptPowerMatch }
                                            , UI.actionButton { label = "Discard", variant = "ghost", msg = ClearPowerMatch }
                                            ]
                                       ]
                                )
                            ]
                        ]

                    Nothing ->
                        []
               )
        )


viewBulkTextSection : Model -> Html Msg
viewBulkTextSection model =
    let
        text =
            bulkStateText model.bulk

        bulkErrorList =
            case model.bulk of
                BulkFailed _ errors ->
                    errors

                _ ->
                    []

        showPreview =
            case model.bulk of
                BulkPreview _ _ ->
                    True

                BulkSaving _ _ ->
                    True

                _ ->
                    False
    in
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Bulk Text Entry"
            , p []
                [ UI.hint "Format: "
                , code [] [ Html.text "{team_number} v {team_number} [{courtroom_name}]" ]
                , br [] []
                , UI.hint "One pairing per line. Courtroom is optional."
                ]
            , UI.textareaField
                { label = ""
                , value = text
                , onInput = BulkTextChanged
                , rows = 8
                , placeholder = "101 v 202 [Dept A]\n103 v 204\n105 v 206 [Dept B]"
                }
            , UI.errorList bulkErrorList
            , if showPreview then
                viewBulkPreview model

              else
                UI.actionRow [ UI.actionButton { label = "Preview", variant = "info", msg = ParseBulkText } ]
            ]
        ]


viewBulkPreview : Model -> Html Msg
viewBulkPreview model =
    let
        ( bulkParsed, saving ) =
            case model.bulk of
                BulkPreview _ parsed ->
                    ( parsed, False )

                BulkSaving _ parsed ->
                    ( parsed, True )

                _ ->
                    ( [], False )
    in
    section [ Attr.class "mt-4" ]
        [ UI.sectionTitle "Preview"
        , UI.dataTable
            { columns = [ "Prosecution", "Defense", "Courtroom" ]
            , rows = bulkParsed
            , rowView =
                \p ->
                    let
                        pTeam =
                            findTeamByNumber model.teams p.prosecutionTeamNumber

                        dTeam =
                            findTeamByNumber model.teams p.defenseTeamNumber
                    in
                    tr []
                        [ td [] [ text (teamLabelFromMaybe pTeam p.prosecutionTeamNumber) ]
                        , td [] [ text (teamLabelFromMaybe dTeam p.defenseTeamNumber) ]
                        , td [] [ text p.courtroomName ]
                        ]
            }
        , UI.actionRow
            [ UI.loadingActionButton
                { label = "Create All"
                , variant = "success"
                , loading = saving
                , disabled = False
                , msg = ConfirmBulkCreate
                }
            , UI.cancelButton CancelBulkPreview
            ]
        ]


viewTrialsTable : Model -> Html Msg
viewTrialsTable model =
    if List.isEmpty model.trials then
        UI.emptyState "No pairings yet for this round."

    else
        section [ Attr.class "mt-6" ]
            [ UI.sectionTitle "Current Pairings"
            , UI.tableWrap
                (table [ Attr.class "table table-zebra w-full" ]
                    [ thead []
                        [ tr []
                            [ th [] [ text "Prosecution" ]
                            , th [] [ text "P History" ]
                            , th [] [ text "Defense" ]
                            , th [] [ text "D History" ]
                            , th [] [ text "Courtroom" ]
                            , th [] [ text "Actions" ]
                            ]
                        ]
                    , tbody []
                        (let
                            allHistory =
                                buildMatchHistory model.teams model.allTrials
                         in
                         List.map
                            (\trial ->
                                let
                                    pTeam =
                                        toDomainTeamFromId model.teams trial.prosecutionTeam

                                    dTeam =
                                        toDomainTeamFromId model.teams trial.defenseTeam

                                    pSides =
                                        pTeam
                                            |> Maybe.map (MatchHistory.sideHistory allHistory)
                                            |> Maybe.withDefault { prosecution = 0, defense = 0 }

                                    dSides =
                                        dTeam
                                            |> Maybe.map (MatchHistory.sideHistory allHistory)
                                            |> Maybe.withDefault { prosecution = 0, defense = 0 }

                                    rematch =
                                        case ( pTeam, dTeam ) of
                                            ( Just p, Just d ) ->
                                                let
                                                    priorHistory =
                                                        buildMatchHistory model.teams
                                                            (List.filter (\t -> t.id /= trial.id) model.allTrials)
                                                in
                                                MatchHistory.hasPlayed priorHistory p d

                                            _ ->
                                                False
                                in
                                tr [ Attr.classList [ ( "bg-warning/20", rematch ) ] ]
                                    [ td [] [ text (teamLabel model.teams trial.prosecutionTeam) ]
                                    , td [] [ text ("P:" ++ String.fromInt pSides.prosecution ++ " D:" ++ String.fromInt pSides.defense) ]
                                    , td [] [ text (teamLabel model.teams trial.defenseTeam) ]
                                    , td [] [ text ("P:" ++ String.fromInt dSides.prosecution ++ " D:" ++ String.fromInt dSides.defense) ]
                                    , td [] [ text (courtroomLabel model.courtrooms trial.courtroom) ]
                                    , td []
                                        [ UI.buttonRow
                                            [ UI.rowActionButton { label = "Edit", variant = "info", loading = False, msg = EditTrial trial }
                                            , UI.rowActionButton { label = "Delete", variant = "error", loading = model.deleting == Just trial.id, msg = DeleteTrial trial.id }
                                            ]
                                        ]
                                    ]
                            )
                            model.trials
                        )
                    ]
                )
            ]



-- HELPERS


teamLabel : List Team -> String -> String
teamLabel teams id =
    List.filter (\t -> t.id == id) teams
        |> List.head
        |> Maybe.map (\t -> String.fromInt t.teamNumber ++ " - " ++ t.name)
        |> Maybe.withDefault id


teamLabelFromMaybe : Maybe Team -> Int -> String
teamLabelFromMaybe maybeTeam num =
    case maybeTeam of
        Just t ->
            String.fromInt t.teamNumber ++ " - " ++ t.name

        Nothing ->
            "Team #" ++ String.fromInt num ++ " (not found)"


courtroomLabel : List Courtroom -> String -> String
courtroomLabel courtrooms id =
    if id == "" then
        "-"

    else
        List.filter (\c -> c.id == id) courtrooms
            |> List.head
            |> Maybe.map .name
            |> Maybe.withDefault id


capitalize : String -> String
capitalize str =
    case String.uncons str of
        Just ( first, rest ) ->
            String.fromChar (Char.toUpper first) ++ rest

        Nothing ->
            str
