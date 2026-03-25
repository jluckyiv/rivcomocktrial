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
        , ProposedPairing
        , RankedTeam
        )
import Route exposing (Route)
import Route.Path
import School
import Shared
import Team as DomainTeam
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init user route
        , update = update user
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


type alias Model =
    { roundId : String
    , round : Maybe Round
    , trials : List Trial
    , teams : List Team
    , courtrooms : List Courtroom
    , allTrials : List Trial
    , loading : Bool
    , formErrors : List String
    , inputMode : InputMode
    , formProsecution : String
    , formDefense : String
    , formCourtroom : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    , bulkText : String
    , bulkParsed : List BulkParsedPairing
    , bulkErrors : List String
    , showBulkPreview : Bool
    , bulkSaving : Bool
    , crossBracketStrategy : CrossBracketStrategy
    , powerMatchResult : Maybe PowerMatchResult
    }


init : Auth.User -> Route () -> () -> ( Model, Effect Msg )
init user route _ =
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
      , formErrors = []
      , inputMode = DropdownMode
      , formProsecution = ""
      , formDefense = ""
      , formCourtroom = ""
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      , bulkText = ""
      , bulkParsed = []
      , bulkErrors = []
      , showBulkPreview = False
      , bulkSaving = False
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


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        SwitchMode mode ->
            ( { model | inputMode = mode }, Effect.none )

        FormProsecutionChanged val ->
            ( { model | formProsecution = val, formErrors = [] }, Effect.none )

        FormDefenseChanged val ->
            ( { model | formDefense = val, formErrors = [] }, Effect.none )

        FormCourtroomChanged val ->
            ( { model | formCourtroom = val, formErrors = [] }, Effect.none )

        SaveTrial ->
            case validateDropdownForm model of
                Err errors ->
                    ( { model | formErrors = errors }, Effect.none )

                Ok data ->
                    ( { model | formSaving = True, formErrors = [] }
                    , case model.editingId of
                        Just id ->
                            Pb.adminUpdate
                                { collection = "trials"
                                , id = id
                                , tag = "save-trial"
                                , body = Api.encodeTrial data
                                }

                        Nothing ->
                            Pb.adminCreate
                                { collection = "trials"
                                , tag = "save-trial"
                                , body = Api.encodeTrial data
                                }
                    )

        EditTrial trial ->
            ( { model
                | editingId = Just trial.id
                , formProsecution = trial.prosecutionTeam
                , formDefense = trial.defenseTeam
                , formCourtroom = trial.courtroom
              }
            , Effect.none
            )

        CancelEdit ->
            ( { model
                | editingId = Nothing
                , formProsecution = ""
                , formDefense = ""
                , formCourtroom = ""
              }
            , Effect.none
            )

        DeleteTrial id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete
                { collection = "trials"
                , id = id
                , tag = "delete-trial"
                }
            )

        BulkTextChanged val ->
            ( { model | bulkText = val, showBulkPreview = False, bulkErrors = [] }, Effect.none )

        ParseBulkText ->
            let
                parsed =
                    parseBulkInput model.bulkText

                errors =
                    validateBulkParsed model.teams parsed
            in
            case errors of
                [] ->
                    ( { model | bulkParsed = parsed, showBulkPreview = True, bulkErrors = [] }, Effect.none )

                _ ->
                    ( { model | bulkErrors = errors, showBulkPreview = False }, Effect.none )

        ConfirmBulkCreate ->
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
                        model.bulkParsed
            in
            ( { model | bulkSaving = True }
            , Effect.batch cmds
            )

        CancelBulkPreview ->
            ( { model | showBulkPreview = False, bulkParsed = [] }, Effect.none )

        SetCrossBracketStrategy strategy ->
            ( { model | crossBracketStrategy = strategy }, Effect.none )

        GeneratePowerMatch ->
            let
                allHistory =
                    buildMatchHistory model.teams model.allTrials

                currentRoundHistory =
                    buildMatchHistory model.teams model.trials

                rankedTeams =
                    buildRankedTeams model.teams model.allTrials

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
                            ( { model | loading = False, formErrors = [ "Failed to load trials." ] }, Effect.none )

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
                            ( { model | formErrors = [ "Failed to load rounds." ] }, Effect.none )

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
                            ( { model | formErrors = [ "Failed to load teams." ] }, Effect.none )

                Just "courtrooms" ->
                    case Pb.decodeList Api.courtroomDecoder value of
                        Ok courtrooms ->
                            ( { model | courtrooms = courtrooms }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-trial" ->
                    case Pb.decodeRecord Api.trialDecoder value of
                        Ok trial ->
                            let
                                updatedTrials =
                                    case model.editingId of
                                        Just _ ->
                                            List.map
                                                (\t ->
                                                    if t.id == trial.id then
                                                        trial

                                                    else
                                                        t
                                                )
                                                model.trials

                                        Nothing ->
                                            model.trials ++ [ trial ]

                                updatedAll =
                                    case model.editingId of
                                        Just _ ->
                                            List.map
                                                (\t ->
                                                    if t.id == trial.id then
                                                        trial

                                                    else
                                                        t
                                                )
                                                model.allTrials

                                        Nothing ->
                                            model.allTrials ++ [ trial ]
                            in
                            ( { model
                                | trials = updatedTrials
                                , allTrials = updatedAll
                                , formProsecution = ""
                                , formDefense = ""
                                , formCourtroom = ""
                                , formSaving = False
                                , editingId = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | formSaving = False, formErrors = [ "Failed to save trial." ] }, Effect.none )

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
                            ( { model | deleting = Nothing, formErrors = [ "Failed to delete trial." ] }, Effect.none )

                Just "bulk-trial" ->
                    case Pb.decodeRecord Api.trialDecoder value of
                        Ok trial ->
                            ( { model
                                | trials = model.trials ++ [ trial ]
                                , allTrials = model.allTrials ++ [ trial ]
                                , bulkSaving = False
                                , showBulkPreview = False
                                , bulkText = ""
                                , bulkParsed = []
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | bulkSaving = False, formErrors = [ "Failed to create some trials." ] }, Effect.none )

                _ ->
                    ( model, Effect.none )



-- VALIDATION


validateDropdownForm :
    Model
    -> Result (List String) { round : String, prosecutionTeam : String, defenseTeam : String, courtroom : String }
validateDropdownForm model =
    let
        errors =
            []
                |> addErrorIf (String.trim model.formProsecution == "") "Prosecution team is required"
                |> addErrorIf (String.trim model.formDefense == "") "Defense team is required"
                |> addErrorIf
                    (model.formProsecution /= "" && model.formProsecution == model.formDefense)
                    "Prosecution and defense cannot be the same team"
    in
    if List.isEmpty errors then
        Ok
            { round = model.roundId
            , prosecutionTeam = model.formProsecution
            , defenseTeam = model.formDefense
            , courtroom = model.formCourtroom
            }

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


buildRankedTeams : List Team -> List Trial -> List RankedTeam
buildRankedTeams teams allTrials =
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
            [ div [ Attr.class "alert alert-warning mb-4" ]
                [ text "No round selected. "
                , a [ Attr.href "/admin/rounds" ] [ text "Go to Rounds" ]
                , text " and click \"Pairings\" on a round."
                ]
            ]

        else
            [ viewHeader model
            , UI.errorList model.formErrors
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
                    "Round " ++ String.fromInt r.number ++ " (" ++ capitalize r.roundType ++ ")"

                Nothing ->
                    "Pairings"
    in
    div [ Attr.class "flex justify-between items-center mb-6" ]
        [ h1 [ Attr.class "text-2xl font-bold" ] [ text roundLabel ]
        , a [ Attr.class "btn btn-ghost", Attr.href "/admin/rounds" ]
            [ text "Back to Rounds" ]
        ]


viewModeToggle : Model -> Html Msg
viewModeToggle model =
    div [ Attr.class "tabs tabs-border mb-4" ]
        [ a
            [ Attr.class
                (if model.inputMode == DropdownMode then
                    "tab tab-active"

                 else
                    "tab"
                )
            , Events.onClick (SwitchMode DropdownMode)
            ]
            [ text "Dropdown" ]
        , a
            [ Attr.class
                (if model.inputMode == BulkTextMode then
                    "tab tab-active"

                 else
                    "tab"
                )
            , Events.onClick (SwitchMode BulkTextMode)
            ]
            [ text "Bulk Text" ]
        ]


viewDropdownForm : Model -> Html Msg
viewDropdownForm model =
    let
        -- Teams already paired in this round (excluding the trial being edited)
        pairedTeamIds =
            model.trials
                |> List.filter (\t -> Just t.id /= model.editingId)
                |> List.concatMap (\t -> [ t.prosecutionTeam, t.defenseTeam ])

        -- Available teams: not yet paired, plus the currently selected values
        availableForProsecution =
            model.teams
                |> List.filter
                    (\t ->
                        t.id == model.formProsecution
                            || not (List.member t.id pairedTeamIds)
                    )
                |> List.filter (\t -> t.id /= model.formDefense || t.id == "")

        availableForDefense =
            model.teams
                |> List.filter
                    (\t ->
                        t.id == model.formDefense
                            || not (List.member t.id pairedTeamIds)
                    )
                |> List.filter (\t -> t.id /= model.formProsecution || t.id == "")

        -- Courtrooms already assigned in this round (excluding the trial being edited)
        usedCourtroomIds =
            model.trials
                |> List.filter (\t -> Just t.id /= model.editingId)
                |> List.map .courtroom
                |> List.filter (\id -> id /= "")

        availableCourtrooms =
            model.courtrooms
                |> List.filter
                    (\c ->
                        c.id == model.formCourtroom
                            || not (List.member c.id usedCourtroomIds)
                    )
    in
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case model.editingId of
                    Just _ ->
                        "Edit Trial"

                    Nothing ->
                        "Add Trial"
                )
            , Html.form [ Events.onSubmit SaveTrial ]
                [ UI.formColumns
                    [ UI.selectField
                        { label = "Prosecution"
                        , value = model.formProsecution
                        , onInput = FormProsecutionChanged
                        , options =
                            { value = "", label = "Select team..." }
                                :: List.map (\t -> { value = t.id, label = String.fromInt t.teamNumber ++ " - " ++ t.name }) availableForProsecution
                        }
                    , UI.selectField
                        { label = "Defense"
                        , value = model.formDefense
                        , onInput = FormDefenseChanged
                        , options =
                            { value = "", label = "Select team..." }
                                :: List.map (\t -> { value = t.id, label = String.fromInt t.teamNumber ++ " - " ++ t.name }) availableForDefense
                        }
                    , UI.selectField
                        { label = "Courtroom"
                        , value = model.formCourtroom
                        , onInput = FormCourtroomChanged
                        , options =
                            { value = "", label = "None" }
                                :: List.map (\c -> { value = c.id, label = c.name }) availableCourtrooms
                        }
                    ]
                , div [ Attr.class "flex gap-2 mt-4" ]
                    [ UI.primaryButton { label = "Save", loading = model.formSaving }
                    , case model.editingId of
                        Just _ ->
                            UI.cancelButton CancelEdit

                        Nothing ->
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
    div [ Attr.class "mb-6" ]
        ([ div [ Attr.class "flex items-center gap-3 flex-wrap" ]
            [ if roundNumber >= 2 then
                div [ Attr.class "flex items-center gap-2" ]
                    [ button [ Attr.class "btn btn-info", Events.onClick GeneratePowerMatch ]
                        [ text "Generate Power Match" ]
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
                    , span [ Attr.class "text-sm text-base-content/70" ]
                        [ text "Cross-bracket strategy" ]
                    ]

              else
                button [ Attr.class "btn btn-info", Events.onClick GeneratePowerMatch ]
                    [ text "Generate Random Pairing" ]
            ]
         ]
            ++ (case model.powerMatchResult of
                    Just result ->
                        [ UI.card
                            [ UI.cardBody
                                ([ UI.cardTitle "Proposed Pairings" ]
                                    ++ List.map
                                        (\w -> div [ Attr.class "alert alert-warning mb-2" ] [ text w ])
                                        result.warnings
                                    ++ [ div [ Attr.class "overflow-x-auto" ]
                                            [ table [ Attr.class "table table-zebra w-full" ]
                                                [ thead []
                                                    [ tr []
                                                        [ th [] [ text "Prosecution" ]
                                                        , th [] [ text "Defense" ]
                                                        ]
                                                    ]
                                                , tbody []
                                                    (List.map
                                                        (\p ->
                                                            tr []
                                                                [ td [] [ text (proposedPairingLabel p.prosecutionTeam) ]
                                                                , td [] [ text (proposedPairingLabel p.defenseTeam) ]
                                                                ]
                                                        )
                                                        result.pairings
                                                    )
                                                ]
                                            ]
                                       , div [ Attr.class "flex gap-2 mt-4" ]
                                            [ button [ Attr.class "btn btn-success", Events.onClick AcceptPowerMatch ]
                                                [ text "Accept & Create" ]
                                            , button [ Attr.class "btn btn-ghost", Events.onClick ClearPowerMatch ]
                                                [ text "Discard" ]
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
    UI.card
        [ UI.cardBody
            [ UI.cardTitle "Bulk Text Entry"
            , p [ Attr.class "text-sm text-base-content/70 mb-3" ]
                [ text "Format: "
                , code [] [ text "{team_number} v {team_number} [{courtroom_name}]" ]
                , br [] []
                , text "One pairing per line. Courtroom is optional."
                ]
            , UI.textareaField
                { label = ""
                , value = model.bulkText
                , onInput = BulkTextChanged
                , rows = 8
                , placeholder = "101 v 202 [Dept A]\n103 v 204\n105 v 206 [Dept B]"
                }
            , UI.errorList model.bulkErrors
            , if model.showBulkPreview then
                viewBulkPreview model

              else
                div [ Attr.class "mt-4" ]
                    [ button [ Attr.class "btn btn-info", Events.onClick ParseBulkText ]
                        [ text "Preview" ]
                    ]
            ]
        ]


viewBulkPreview : Model -> Html Msg
viewBulkPreview model =
    div [ Attr.class "mt-4" ]
        [ h3 [ Attr.class "font-semibold mb-2" ] [ text "Preview" ]
        , div [ Attr.class "overflow-x-auto" ]
            [ table [ Attr.class "table table-zebra w-full" ]
                [ thead []
                    [ tr []
                        [ th [] [ text "Prosecution" ]
                        , th [] [ text "Defense" ]
                        , th [] [ text "Courtroom" ]
                        ]
                    ]
                , tbody []
                    (List.map
                        (\p ->
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
                        )
                        model.bulkParsed
                    )
                ]
            ]
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-success"
                , Events.onClick ConfirmBulkCreate
                , Attr.disabled model.bulkSaving
                ]
                (if model.bulkSaving then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Creating..."
                    ]

                 else
                    [ text "Create All" ]
                )
            , UI.cancelButton CancelBulkPreview
            ]
        ]


viewTrialsTable : Model -> Html Msg
viewTrialsTable model =
    if List.isEmpty model.trials then
        UI.emptyState "No pairings yet for this round."

    else
        div [ Attr.class "mt-6" ]
            [ h2 [ Attr.class "text-lg font-semibold mb-3" ] [ text "Current Pairings" ]
            , div [ Attr.class "overflow-x-auto" ]
                [ table [ Attr.class "table table-zebra w-full" ]
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
                                tr
                                    [ Attr.class
                                        (if rematch then
                                            "bg-warning/20"

                                         else
                                            ""
                                        )
                                    ]
                                    [ td [] [ text (teamLabel model.teams trial.prosecutionTeam) ]
                                    , td [] [ text ("P:" ++ String.fromInt pSides.prosecution ++ " D:" ++ String.fromInt pSides.defense) ]
                                    , td [] [ text (teamLabel model.teams trial.defenseTeam) ]
                                    , td [] [ text ("P:" ++ String.fromInt dSides.prosecution ++ " D:" ++ String.fromInt dSides.defense) ]
                                    , td [] [ text (courtroomLabel model.courtrooms trial.courtroom) ]
                                    , td []
                                        [ div [ Attr.class "flex gap-2" ]
                                            [ button
                                                [ Attr.class "btn btn-sm btn-outline btn-info"
                                                , Events.onClick (EditTrial trial)
                                                ]
                                                [ text "Edit" ]
                                            , button
                                                [ Attr.class "btn btn-sm btn-outline btn-error"
                                                , Events.onClick (DeleteTrial trial.id)
                                                , Attr.disabled (model.deleting == Just trial.id)
                                                ]
                                                (if model.deleting == Just trial.id then
                                                    [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                                                 else
                                                    [ text "Delete" ]
                                                )
                                            ]
                                        ]
                                    ]
                            )
                            model.trials
                        )
                    ]
                ]
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
