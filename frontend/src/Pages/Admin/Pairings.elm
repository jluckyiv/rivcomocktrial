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
import Http
import Layouts
import MatchHistory exposing (MatchHistory)
import Page exposing (Page)
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
            [ Effect.sendCmd (Api.listTrialsByRound user.token roundId GotTrials)
            , Effect.sendCmd (Api.listTrials user.token GotAllTrials)
            , Effect.sendCmd (Api.listRounds user.token GotRounds)
            , Effect.sendCmd (Api.listCourtrooms user.token GotCourtrooms)
            ]
    )



-- UPDATE


type Msg
    = GotRounds (Result Http.Error (Api.ListResponse Round))
    | GotTrials (Result Http.Error (Api.ListResponse Trial))
    | GotAllTrials (Result Http.Error (Api.ListResponse Trial))
    | GotTeams (Result Http.Error (Api.ListResponse Team))
    | GotCourtrooms (Result Http.Error (Api.ListResponse Courtroom))
    | SwitchMode InputMode
    | FormProsecutionChanged String
    | FormDefenseChanged String
    | FormCourtroomChanged String
    | SaveTrial
    | GotSaveResponse (Result Http.Error Trial)
    | EditTrial Trial
    | CancelEdit
    | DeleteTrial String
    | GotDeleteResponse String (Result Http.Error ())
    | BulkTextChanged String
    | ParseBulkText
    | ConfirmBulkCreate
    | GotBulkCreateResponse (Result Http.Error Trial)
    | CancelBulkPreview
    | SetCrossBracketStrategy CrossBracketStrategy
    | GeneratePowerMatch
    | AcceptPowerMatch
    | ClearPowerMatch


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotRounds (Ok response) ->
            let
                round =
                    List.filter (\r -> r.id == model.roundId) response.items
                        |> List.head

                tournamentId =
                    round |> Maybe.map .tournament |> Maybe.withDefault ""
            in
            ( { model | round = round }
            , if tournamentId /= "" then
                Effect.sendCmd (Api.listTeams user.token GotTeams)

              else
                Effect.none
            )

        GotRounds (Err _) ->
            ( { model | formErrors = [ "Failed to load rounds." ] }, Effect.none )

        GotTrials (Ok response) ->
            ( { model | trials = response.items, loading = False }, Effect.none )

        GotTrials (Err _) ->
            ( { model | loading = False, formErrors = [ "Failed to load trials." ] }, Effect.none )

        GotAllTrials (Ok response) ->
            ( { model | allTrials = response.items }, Effect.none )

        GotAllTrials (Err _) ->
            ( model, Effect.none )

        GotTeams (Ok response) ->
            let
                tournamentId =
                    model.round |> Maybe.map .tournament |> Maybe.withDefault ""

                filtered =
                    List.filter (\t -> t.tournament == tournamentId) response.items
            in
            ( { model | teams = filtered }, Effect.none )

        GotTeams (Err _) ->
            ( { model | formErrors = [ "Failed to load teams." ] }, Effect.none )

        GotCourtrooms (Ok response) ->
            ( { model | courtrooms = response.items }, Effect.none )

        GotCourtrooms (Err _) ->
            ( model, Effect.none )

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
                    let
                        cmd =
                            case model.editingId of
                                Just id ->
                                    Api.updateTrial user.token id data GotSaveResponse

                                Nothing ->
                                    Api.createTrial user.token data GotSaveResponse
                    in
                    ( { model | formSaving = True, formErrors = [] }, Effect.sendCmd cmd )

        GotSaveResponse (Ok trial) ->
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

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, formErrors = [ "Failed to save trial." ] }, Effect.none )

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
            , Effect.sendCmd (Api.deleteTrial user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | trials = List.filter (\t -> t.id /= id) model.trials
                , allTrials = List.filter (\t -> t.id /= id) model.allTrials
                , deleting = Nothing
              }
            , Effect.none
            )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, formErrors = [ "Failed to delete trial." ] }, Effect.none )

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
                                        (Api.createTrial user.token
                                            { round = model.roundId
                                            , prosecutionTeam = pt.id
                                            , defenseTeam = dt.id
                                            , courtroom = courtroom |> Maybe.map .id |> Maybe.withDefault ""
                                            }
                                            GotBulkCreateResponse
                                        )

                                _ ->
                                    Nothing
                        )
                        model.bulkParsed
            in
            ( { model | bulkSaving = True }
            , Effect.batch (List.map Effect.sendCmd cmds)
            )

        GotBulkCreateResponse (Ok trial) ->
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

        GotBulkCreateResponse (Err _) ->
            ( { model | bulkSaving = False, formErrors = [ "Failed to create some trials." ] }, Effect.none )

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
                                                (Api.createTrial user.token
                                                    { round = model.roundId
                                                    , prosecutionTeam = pId
                                                    , defenseTeam = dId
                                                    , courtroom = ""
                                                    }
                                                    GotSaveResponse
                                                )

                                        _ ->
                                            Nothing
                                )
                                result.pairings
                    in
                    ( { model | powerMatchResult = Nothing }
                    , Effect.batch (List.map Effect.sendCmd cmds)
                    )

        ClearPowerMatch ->
            ( { model | powerMatchResult = Nothing }, Effect.none )



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
addErrorIf condition error errors =
    if condition then
        errors ++ [ error ]

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
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Pairings"
    , body =
        if model.roundId == "" then
            [ div [ Attr.class "notification is-warning" ]
                [ text "No round selected. "
                , a [ Attr.href "/admin/rounds" ] [ text "Go to Rounds" ]
                , text " and click \"Pairings\" on a round."
                ]
            ]

        else
            [ viewHeader model
            , viewErrors model.formErrors
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
                div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

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
    div [ Attr.class "level" ]
        [ div [ Attr.class "level-left" ]
            [ h1 [ Attr.class "title" ] [ text roundLabel ]
            ]
        , div [ Attr.class "level-right" ]
            [ a [ Attr.class "button is-light", Attr.href "/admin/rounds" ]
                [ text "Back to Rounds" ]
            ]
        ]


viewErrors : List String -> Html msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "notification is-danger is-light" ]
            [ ul [] (List.map (\e -> li [] [ text e ]) errors) ]


viewModeToggle : Model -> Html Msg
viewModeToggle model =
    div [ Attr.class "tabs is-boxed mb-4" ]
        [ ul []
            [ li
                [ Attr.class
                    (if model.inputMode == DropdownMode then
                        "is-active"

                     else
                        ""
                    )
                ]
                [ a [ Events.onClick (SwitchMode DropdownMode) ] [ text "Dropdown" ] ]
            , li
                [ Attr.class
                    (if model.inputMode == BulkTextMode then
                        "is-active"

                     else
                        ""
                    )
                ]
                [ a [ Events.onClick (SwitchMode BulkTextMode) ] [ text "Bulk Text" ] ]
            ]
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
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case model.editingId of
                    Just _ ->
                        "Edit Trial"

                    Nothing ->
                        "Add Trial"
                )
            ]
        , Html.form [ Events.onSubmit SaveTrial ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Prosecution" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormProsecutionChanged ]
                                    (option [ Attr.value "" ] [ text "Select team..." ]
                                        :: List.map
                                            (\t ->
                                                option [ Attr.value t.id, Attr.selected (model.formProsecution == t.id) ]
                                                    [ text (String.fromInt t.teamNumber ++ " - " ++ t.name) ]
                                            )
                                            availableForProsecution
                                    )
                                ]
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Defense" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormDefenseChanged ]
                                    (option [ Attr.value "" ] [ text "Select team..." ]
                                        :: List.map
                                            (\t ->
                                                option [ Attr.value t.id, Attr.selected (model.formDefense == t.id) ]
                                                    [ text (String.fromInt t.teamNumber ++ " - " ++ t.name) ]
                                            )
                                            availableForDefense
                                    )
                                ]
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Courtroom" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormCourtroomChanged ]
                                    (option [ Attr.value "" ] [ text "None" ]
                                        :: List.map
                                            (\c ->
                                                option [ Attr.value c.id, Attr.selected (model.formCourtroom == c.id) ]
                                                    [ text c.name ]
                                            )
                                            availableCourtrooms
                                    )
                                ]
                            ]
                        ]
                    ]
                ]
            , div [ Attr.class "field is-grouped" ]
                [ div [ Attr.class "control" ]
                    [ button
                        [ Attr.class
                            (if model.formSaving then
                                "button is-primary is-loading"

                             else
                                "button is-primary"
                            )
                        , Attr.type_ "submit"
                        ]
                        [ text "Save" ]
                    ]
                , case model.editingId of
                    Just _ ->
                        div [ Attr.class "control" ]
                            [ button [ Attr.class "button", Attr.type_ "button", Events.onClick CancelEdit ]
                                [ text "Cancel" ]
                            ]

                    Nothing ->
                        text ""
                ]
            ]
        ]


viewPowerMatchSection : Model -> Html Msg
viewPowerMatchSection model =
    let
        roundNumber =
            model.round |> Maybe.map .number |> Maybe.withDefault 1
    in
    div [ Attr.class "mb-5" ]
        ([ if roundNumber >= 2 then
            div [ Attr.class "field is-grouped is-align-items-center" ]
                [ div [ Attr.class "control" ]
                    [ button [ Attr.class "button is-info", Events.onClick GeneratePowerMatch ]
                        [ text "Generate Power Match" ]
                    ]
                , div [ Attr.class "control" ]
                    [ div [ Attr.class "select" ]
                        [ select
                            [ Events.onInput
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
                        ]
                    ]
                , div [ Attr.class "control" ]
                    [ span [ Attr.class "help" ]
                        [ text "Cross-bracket pairing strategy" ]
                    ]
                ]

           else
            button [ Attr.class "button is-info", Events.onClick GeneratePowerMatch ]
                [ text "Generate Random Pairing" ]
         ]
            ++ (case model.powerMatchResult of
                    Just result ->
                        [ div [ Attr.class "box mt-4" ]
                            ([ h3 [ Attr.class "subtitle" ] [ text "Proposed Pairings" ] ]
                                ++ List.map
                                    (\w -> div [ Attr.class "notification is-warning is-light" ] [ text w ])
                                    result.warnings
                                ++ [ table [ Attr.class "table is-fullwidth" ]
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
                                   , div [ Attr.class "field is-grouped" ]
                                        [ div [ Attr.class "control" ]
                                            [ button [ Attr.class "button is-success", Events.onClick AcceptPowerMatch ]
                                                [ text "Accept & Create" ]
                                            ]
                                        , div [ Attr.class "control" ]
                                            [ button [ Attr.class "button", Events.onClick ClearPowerMatch ]
                                                [ text "Discard" ]
                                            ]
                                        ]
                                   ]
                            )
                        ]

                    Nothing ->
                        []
               )
        )


viewBulkTextSection : Model -> Html Msg
viewBulkTextSection model =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ] [ text "Bulk Text Entry" ]
        , p [ Attr.class "help mb-3" ]
            [ text "Format: "
            , code [] [ text "{team_number} v {team_number} [{courtroom_name}]" ]
            , br [] []
            , text "One pairing per line. Courtroom is optional."
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ textarea
                    [ Attr.class "textarea"
                    , Attr.rows 8
                    , Attr.placeholder "101 v 202 [Dept A]\n103 v 204\n105 v 206 [Dept B]"
                    , Attr.value model.bulkText
                    , Events.onInput BulkTextChanged
                    ]
                    []
                ]
            ]
        , viewErrors model.bulkErrors
        , if model.showBulkPreview then
            viewBulkPreview model

          else
            div [ Attr.class "field" ]
                [ button [ Attr.class "button is-info", Events.onClick ParseBulkText ]
                    [ text "Preview" ]
                ]
        ]


viewBulkPreview : Model -> Html Msg
viewBulkPreview model =
    div [ Attr.class "mt-4" ]
        [ h3 [ Attr.class "subtitle is-5" ] [ text "Preview" ]
        , table [ Attr.class "table is-fullwidth" ]
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
        , div [ Attr.class "field is-grouped" ]
            [ div [ Attr.class "control" ]
                [ button
                    [ Attr.class
                        (if model.bulkSaving then
                            "button is-success is-loading"

                         else
                            "button is-success"
                        )
                    , Events.onClick ConfirmBulkCreate
                    ]
                    [ text "Create All" ]
                ]
            , div [ Attr.class "control" ]
                [ button [ Attr.class "button", Events.onClick CancelBulkPreview ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewTrialsTable : Model -> Html Msg
viewTrialsTable model =
    if List.isEmpty model.trials then
        div [ Attr.class "has-text-centered has-text-grey mt-5" ]
            [ p [] [ text "No pairings yet for this round." ] ]

    else
        div [ Attr.class "mt-5" ]
            [ h2 [ Attr.class "subtitle" ] [ text "Current Pairings" ]
            , table [ Attr.class "table is-fullwidth is-striped" ]
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
                                        "has-background-warning-light"

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
                                    [ div [ Attr.class "buttons are-small" ]
                                        [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditTrial trial) ]
                                            [ text "Edit" ]
                                        , button
                                            [ Attr.class
                                                (if model.deleting == Just trial.id then
                                                    "button is-danger is-outlined is-loading"

                                                 else
                                                    "button is-danger is-outlined"
                                                )
                                            , Events.onClick (DeleteTrial trial.id)
                                            ]
                                            [ text "Delete" ]
                                        ]
                                    ]
                                ]
                        )
                        model.trials
                    )
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
