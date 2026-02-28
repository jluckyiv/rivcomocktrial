module Pages.Admin.Pairings exposing (Model, Msg, page)

import Api exposing (Courtroom, Round, Team, Trial)
import Auth
import Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
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


type alias SideCount =
    { prosecution : Int
    , defense : Int
    }


type alias PowerMatchResult =
    { pairings : List ProposedPairing
    , warnings : List String
    , bye : Maybe String
    }


type alias ProposedPairing =
    { prosecutionTeam : String
    , defenseTeam : String
    }


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
    , error : Maybe String
    , inputMode : InputMode
    , formProsecution : String
    , formDefense : String
    , formCourtroom : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    , bulkText : String
    , bulkParsed : List BulkParsedPairing
    , bulkError : Maybe String
    , showBulkPreview : Bool
    , bulkSaving : Bool
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
      , error = Nothing
      , inputMode = DropdownMode
      , formProsecution = ""
      , formDefense = ""
      , formCourtroom = ""
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      , bulkText = ""
      , bulkParsed = []
      , bulkError = Nothing
      , showBulkPreview = False
      , bulkSaving = False
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
            ( { model | error = Just "Failed to load rounds." }, Effect.none )

        GotTrials (Ok response) ->
            ( { model | trials = response.items, loading = False }, Effect.none )

        GotTrials (Err _) ->
            ( { model | loading = False, error = Just "Failed to load trials." }, Effect.none )

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
            ( { model | error = Just "Failed to load teams." }, Effect.none )

        GotCourtrooms (Ok response) ->
            ( { model | courtrooms = response.items }, Effect.none )

        GotCourtrooms (Err _) ->
            ( model, Effect.none )

        SwitchMode mode ->
            ( { model | inputMode = mode }, Effect.none )

        FormProsecutionChanged val ->
            ( { model | formProsecution = val }, Effect.none )

        FormDefenseChanged val ->
            ( { model | formDefense = val }, Effect.none )

        FormCourtroomChanged val ->
            ( { model | formCourtroom = val }, Effect.none )

        SaveTrial ->
            if model.formProsecution == model.formDefense then
                ( { model | error = Just "Prosecution and defense cannot be the same team." }, Effect.none )

            else
                let
                    data =
                        { round = model.roundId
                        , prosecutionTeam = model.formProsecution
                        , defenseTeam = model.formDefense
                        , courtroom = model.formCourtroom
                        }

                    cmd =
                        case model.editingId of
                            Just id ->
                                Api.updateTrial user.token id data GotSaveResponse

                            Nothing ->
                                Api.createTrial user.token data GotSaveResponse
                in
                ( { model | formSaving = True, error = Nothing }, Effect.sendCmd cmd )

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
            ( { model | formSaving = False, error = Just "Failed to save trial." }, Effect.none )

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
            ( { model | deleting = Nothing, error = Just "Failed to delete trial." }, Effect.none )

        BulkTextChanged val ->
            ( { model | bulkText = val, showBulkPreview = False, bulkError = Nothing }, Effect.none )

        ParseBulkText ->
            let
                parsed =
                    parseBulkInput model.bulkText

                errors =
                    validateBulkParsed model.teams parsed
            in
            case errors of
                [] ->
                    ( { model | bulkParsed = parsed, showBulkPreview = True, bulkError = Nothing }, Effect.none )

                _ ->
                    ( { model | bulkError = Just (String.join "; " errors), showBulkPreview = False }, Effect.none )

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
            ( { model | bulkSaving = False, error = Just "Failed to create some trials." }, Effect.none )

        CancelBulkPreview ->
            ( { model | showBulkPreview = False, bulkParsed = [] }, Effect.none )

        GeneratePowerMatch ->
            let
                result =
                    powerMatch model.teams model.allTrials model.trials
            in
            ( { model | powerMatchResult = Just result }, Effect.none )

        AcceptPowerMatch ->
            case model.powerMatchResult of
                Just result ->
                    let
                        cmds =
                            List.map
                                (\p ->
                                    Api.createTrial user.token
                                        { round = model.roundId
                                        , prosecutionTeam = p.prosecutionTeam
                                        , defenseTeam = p.defenseTeam
                                        , courtroom = ""
                                        }
                                        GotSaveResponse
                                )
                                result.pairings
                    in
                    ( { model | powerMatchResult = Nothing }
                    , Effect.batch (List.map Effect.sendCmd cmds)
                    )

                Nothing ->
                    ( model, Effect.none )

        ClearPowerMatch ->
            ( { model | powerMatchResult = Nothing }, Effect.none )



-- POWER MATCHING


hasPlayed : List Trial -> String -> String -> Bool
hasPlayed trials teamA teamB =
    List.any
        (\t ->
            (t.prosecutionTeam == teamA && t.defenseTeam == teamB)
                || (t.prosecutionTeam == teamB && t.defenseTeam == teamA)
        )
        trials


sideHistory : List Trial -> String -> SideCount
sideHistory trials teamId =
    List.foldl
        (\t acc ->
            if t.prosecutionTeam == teamId then
                { acc | prosecution = acc.prosecution + 1 }

            else if t.defenseTeam == teamId then
                { acc | defense = acc.defense + 1 }

            else
                acc
        )
        { prosecution = 0, defense = 0 }
        trials


powerMatch : List Team -> List Trial -> List Trial -> PowerMatchResult
powerMatch teams allTrials currentRoundTrials =
    let
        -- Filter out teams already paired in this round
        pairedTeamIds =
            List.concatMap (\t -> [ t.prosecutionTeam, t.defenseTeam ]) currentRoundTrials

        availableTeams =
            List.filter (\t -> not (List.member t.id pairedTeamIds)) teams

        -- Sort by side balance (fewer prosecution appearances first)
        sortedTeams =
            List.sortBy
                (\t ->
                    let
                        sides =
                            sideHistory allTrials t.id
                    in
                    sides.prosecution - sides.defense
                )
                availableTeams

        -- Handle bye for odd team count
        ( teamsToMatch, bye ) =
            if modBy 2 (List.length sortedTeams) == 1 then
                ( List.take (List.length sortedTeams - 1) sortedTeams
                , List.drop (List.length sortedTeams - 1) sortedTeams
                    |> List.head
                    |> Maybe.map .id
                )

            else
                ( sortedTeams, Nothing )

        -- Simple greedy pairing: take first, find best opponent
        pairings =
            greedyPair allTrials teamsToMatch []

        warnings =
            List.filterMap
                (\p ->
                    if hasPlayed allTrials p.prosecutionTeam p.defenseTeam then
                        Just ("Rematch: " ++ p.prosecutionTeam ++ " vs " ++ p.defenseTeam)

                    else
                        Nothing
                )
                pairings
    in
    { pairings = pairings
    , warnings = warnings
    , bye = bye
    }


greedyPair : List Trial -> List Team -> List ProposedPairing -> List ProposedPairing
greedyPair allTrials remaining acc =
    case remaining of
        [] ->
            List.reverse acc

        [ _ ] ->
            List.reverse acc

        first :: rest ->
            let
                -- Find best opponent: prefer non-rematch
                bestOpponent =
                    rest
                        |> List.sortBy
                            (\t ->
                                if hasPlayed allTrials first.id t.id then
                                    1

                                else
                                    0
                            )
                        |> List.head
            in
            case bestOpponent of
                Just opp ->
                    let
                        firstSides =
                            sideHistory allTrials first.id

                        oppSides =
                            sideHistory allTrials opp.id

                        ( pTeam, dTeam ) =
                            if firstSides.prosecution <= oppSides.prosecution then
                                ( first.id, opp.id )

                            else
                                ( opp.id, first.id )

                        newRemaining =
                            List.filter (\t -> t.id /= opp.id) rest
                    in
                    greedyPair allTrials
                        newRemaining
                        ({ prosecutionTeam = pTeam, defenseTeam = dTeam } :: acc)

                Nothing ->
                    List.reverse acc



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
            , viewError model.error
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


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Just err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Nothing ->
            text ""


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
            button [ Attr.class "button is-info", Events.onClick GeneratePowerMatch ]
                [ text "Generate Power Match" ]

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
                                ++ (case result.bye of
                                        Just byeTeamId ->
                                            [ div [ Attr.class "notification is-info is-light" ]
                                                [ text ("Bye: " ++ teamLabel model.teams byeTeamId) ]
                                            ]

                                        Nothing ->
                                            []
                                   )
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
                                                        [ td [] [ text (teamLabel model.teams p.prosecutionTeam) ]
                                                        , td [] [ text (teamLabel model.teams p.defenseTeam) ]
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
        , case model.bulkError of
            Just err ->
                div [ Attr.class "notification is-danger is-light" ] [ text err ]

            Nothing ->
                text ""
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
                    (List.map
                        (\trial ->
                            let
                                pSides =
                                    sideHistory model.allTrials trial.prosecutionTeam

                                dSides =
                                    sideHistory model.allTrials trial.defenseTeam

                                rematch =
                                    let
                                        priorTrials =
                                            List.filter (\t -> t.id /= trial.id) model.allTrials
                                    in
                                    hasPlayed priorTrials trial.prosecutionTeam trial.defenseTeam
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
