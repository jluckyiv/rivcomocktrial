module Pages.Admin.Rosters exposing (Model, Msg, page)

import Api exposing (CaseCharacter, RosterEntry, RosterSubmission, Round, Student, Team, Tournament)
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import RemoteData exposing (RemoteData(..))
import RosterForm
import Route exposing (Route)
import Shared
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ _ _ =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type alias SelectedCell =
    { teamId : String
    , roundId : String
    , side : Api.RosterSide
    }


type alias Model =
    { tournaments : List Tournament
    , teams : RemoteData (List Team)
    , rounds : RemoteData (List Round)
    , submissions : RemoteData (List RosterSubmission)
    , entries : List RosterEntry
    , caseCharacters : List CaseCharacter
    , students : List Student
    , filterTournament : String
    , filterRound : String
    , selectedCell : Maybe SelectedCell
    , form : RosterForm.FormState
    , savesPending : Int
    , deletesPending : Int
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { tournaments = []
      , teams = Loading
      , rounds = Loading
      , submissions = Loading
      , entries = []
      , caseCharacters = []
      , students = []
      , filterTournament = ""
      , filterRound = ""
      , selectedCell = Nothing
      , form = RosterForm.FormHidden
      , savesPending = 0
      , deletesPending = 0
      }
    , Effect.batch
        [ Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
        , Pb.adminList { collection = "teams", tag = "teams", filter = "", sort = "name" }
        , Pb.adminList { collection = "rounds", tag = "rounds", filter = "", sort = "number" }
        , Pb.adminList { collection = "roster_submissions", tag = "submissions", filter = "", sort = "" }
        , Pb.adminList { collection = "roster_entries", tag = "entries", filter = "", sort = "side,sort_order" }
        , Pb.adminList { collection = "case_characters", tag = "case-characters", filter = "", sort = "side,sort_order" }
        , Pb.adminList { collection = "students", tag = "students", filter = "", sort = "name" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterTournamentChanged String
    | FilterRoundChanged String
    | SelectCell String String Api.RosterSide
    | CloseCell
    | EditRoster
    | CancelForm
    | AddRow
    | RemoveRow Int
    | UpdateRowStudent Int String
    | UpdateRowEntryType Int String
    | UpdateRowRole Int String
    | UpdateRowCharacter Int String
    | SaveDraft
    | SubmitRoster


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            handlePbMsg value model

        FilterTournamentChanged val ->
            ( { model | filterTournament = val }, Effect.none )

        FilterRoundChanged val ->
            ( { model | filterRound = val }, Effect.none )

        SelectCell teamId roundId side ->
            ( { model
                | selectedCell = Just { teamId = teamId, roundId = roundId, side = side }
                , form = RosterForm.FormHidden
              }
            , Effect.none
            )

        CloseCell ->
            ( { model | selectedCell = Nothing, form = RosterForm.FormHidden }, Effect.none )

        EditRoster ->
            case model.selectedCell of
                Just cell ->
                    let
                        existingEntries =
                            entriesForCell cell.teamId cell.roundId cell.side model.entries

                        rows =
                            if List.isEmpty existingEntries then
                                [ RosterForm.emptyRow ]

                            else
                                List.map RosterForm.entryToFormRow existingEntries
                    in
                    ( { model
                        | form =
                            RosterForm.FormEditing
                                { teamId = cell.teamId
                                , roundId = cell.roundId
                                , side = cell.side
                                , rows = rows
                                }
                                []
                      }
                    , Effect.none
                    )

                Nothing ->
                    ( model, Effect.none )

        CancelForm ->
            ( { model | form = RosterForm.FormHidden }, Effect.none )

        AddRow ->
            ( { model | form = RosterForm.updateFormRows (\rows -> rows ++ [ RosterForm.emptyRow ]) model.form }
            , Effect.none
            )

        RemoveRow idx ->
            ( { model
                | form =
                    RosterForm.updateFormRows
                        (\rows ->
                            List.indexedMap Tuple.pair rows
                                |> List.filterMap
                                    (\( i, r ) ->
                                        if i == idx then
                                            Nothing

                                        else
                                            Just r
                                    )
                        )
                        model.form
              }
            , Effect.none
            )

        UpdateRowStudent idx val ->
            ( { model | form = RosterForm.updateRow idx (\r -> { r | student = val }) model.form }, Effect.none )

        UpdateRowEntryType idx val ->
            ( { model | form = RosterForm.updateRowEntryType idx val model.form }, Effect.none )

        UpdateRowRole idx val ->
            ( { model | form = RosterForm.updateRowRole idx val model.form }, Effect.none )

        UpdateRowCharacter idx val ->
            ( { model | form = RosterForm.updateRow idx (\r -> { r | character = val }) model.form }, Effect.none )

        SaveDraft ->
            handleSave False model

        SubmitRoster ->
            handleSave True model


handleSave : Bool -> Model -> ( Model, Effect Msg )
handleSave submitting model =
    case model.form of
        RosterForm.FormEditing formData _ ->
            case RosterForm.validateForm formData of
                Err errors ->
                    ( { model | form = RosterForm.FormEditing formData errors }, Effect.none )

                Ok validRows ->
                    let
                        existingEntries =
                            entriesForCell formData.teamId formData.roundId formData.side model.entries

                        existingIds =
                            List.filterMap .id validRows

                        toDelete =
                            List.filter
                                (\e -> not (List.member e.id existingIds))
                                existingEntries

                        toCreate =
                            List.filter (\r -> r.id == Nothing) validRows

                        toUpdate =
                            List.filter (\r -> r.id /= Nothing) validRows

                        encodeRow row =
                            Api.encodeRosterEntry
                                { team = formData.teamId
                                , round = formData.roundId
                                , side = formData.side
                                , student =
                                    if row.student == "" then
                                        Nothing

                                    else
                                        Just row.student
                                , entryType = row.entryType
                                , role = row.role
                                , character =
                                    if row.character == "" then
                                        Nothing

                                    else
                                        Just row.character
                                , sortOrder = Nothing
                                }

                        createEffects =
                            List.map
                                (\row ->
                                    Pb.adminCreate
                                        { collection = "roster_entries"
                                        , tag = "save-entry"
                                        , body = encodeRow row
                                        }
                                )
                                toCreate

                        updateEffects =
                            List.filterMap
                                (\row ->
                                    row.id
                                        |> Maybe.map
                                            (\id ->
                                                Pb.adminUpdate
                                                    { collection = "roster_entries"
                                                    , id = id
                                                    , tag = "save-entry"
                                                    , body = encodeRow row
                                                    }
                                            )
                                )
                                toUpdate

                        deleteEffects =
                            List.map
                                (\entry ->
                                    Pb.adminDelete
                                        { collection = "roster_entries"
                                        , id = entry.id
                                        , tag = "delete-entry"
                                        }
                                )
                                toDelete

                        submissionEffect =
                            let
                                existingSub =
                                    submissionForCell formData.teamId formData.roundId formData.side model.submissions

                                submittedAt =
                                    if submitting then
                                        Just "now"

                                    else
                                        Nothing

                                body =
                                    Api.encodeRosterSubmission
                                        { team = formData.teamId
                                        , round = formData.roundId
                                        , side = formData.side
                                        , submittedAt = submittedAt
                                        }
                            in
                            case existingSub of
                                Just sub ->
                                    [ Pb.adminUpdate
                                        { collection = "roster_submissions"
                                        , id = sub.id
                                        , tag = "save-submission"
                                        , body = body
                                        }
                                    ]

                                Nothing ->
                                    [ Pb.adminCreate
                                        { collection = "roster_submissions"
                                        , tag = "save-submission"
                                        , body = body
                                        }
                                    ]

                        allEffects =
                            createEffects ++ updateEffects ++ deleteEffects ++ submissionEffect
                    in
                    ( { model
                        | form =
                            if submitting then
                                RosterForm.FormSubmitting formData

                            else
                                RosterForm.FormSavingDraft formData
                        , savesPending = List.length createEffects + List.length updateEffects + List.length submissionEffect
                        , deletesPending = List.length deleteEffects
                      }
                    , Effect.batch allEffects
                    )

        _ ->
            ( model, Effect.none )


handlePbMsg : Json.Decode.Value -> Model -> ( Model, Effect Msg )
handlePbMsg value model =
    case Pb.responseTag value of
        Just "tournaments" ->
            case Pb.decodeList Api.tournamentDecoder value of
                Ok items ->
                    ( { model | tournaments = items }, Effect.none )

                Err _ ->
                    ( model, Effect.none )

        Just "teams" ->
            case Pb.decodeList Api.teamDecoder value of
                Ok items ->
                    ( { model | teams = Succeeded items }, Effect.none )

                Err _ ->
                    ( { model | teams = Failed "Failed to load teams." }, Effect.none )

        Just "rounds" ->
            case Pb.decodeList Api.roundDecoder value of
                Ok items ->
                    ( { model | rounds = Succeeded items }, Effect.none )

                Err _ ->
                    ( { model | rounds = Failed "Failed to load rounds." }, Effect.none )

        Just "submissions" ->
            case Pb.decodeList Api.rosterSubmissionDecoder value of
                Ok items ->
                    ( { model | submissions = Succeeded items }, Effect.none )

                Err _ ->
                    ( { model | submissions = Failed "Failed to load submissions." }, Effect.none )

        Just "entries" ->
            case Pb.decodeList Api.rosterEntryDecoder value of
                Ok items ->
                    ( { model | entries = items }, Effect.none )

                Err _ ->
                    ( model, Effect.none )

        Just "case-characters" ->
            case Pb.decodeList Api.caseCharacterDecoder value of
                Ok items ->
                    ( { model | caseCharacters = items }, Effect.none )

                Err _ ->
                    ( model, Effect.none )

        Just "students" ->
            case Pb.decodeList Api.studentDecoder value of
                Ok items ->
                    ( { model | students = items }, Effect.none )

                Err _ ->
                    ( model, Effect.none )

        Just "save-entry" ->
            case Pb.decodeRecord Api.rosterEntryDecoder value of
                Ok entry ->
                    let
                        updatedEntries =
                            if List.any (\e -> e.id == entry.id) model.entries then
                                List.map
                                    (\e ->
                                        if e.id == entry.id then
                                            entry

                                        else
                                            e
                                    )
                                    model.entries

                            else
                                model.entries ++ [ entry ]

                        newPending =
                            model.savesPending - 1
                    in
                    checkSaveComplete
                        { model
                            | entries = updatedEntries
                            , savesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to save roster entry." model

        Just "delete-entry" ->
            case Pb.decodeDelete value of
                Ok id ->
                    let
                        newPending =
                            model.deletesPending - 1
                    in
                    checkSaveComplete
                        { model
                            | entries = List.filter (\e -> e.id /= id) model.entries
                            , deletesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to delete roster entry." model

        Just "save-submission" ->
            case Pb.decodeRecord Api.rosterSubmissionDecoder value of
                Ok sub ->
                    let
                        updatedSubs =
                            case model.submissions of
                                Succeeded subs ->
                                    if List.any (\s -> s.id == sub.id) subs then
                                        Succeeded
                                            (List.map
                                                (\s ->
                                                    if s.id == sub.id then
                                                        sub

                                                    else
                                                        s
                                                )
                                                subs
                                            )

                                    else
                                        Succeeded (subs ++ [ sub ])

                                _ ->
                                    Succeeded [ sub ]

                        newPending =
                            model.savesPending - 1
                    in
                    checkSaveComplete
                        { model
                            | submissions = updatedSubs
                            , savesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to save submission." model

        _ ->
            ( model, Effect.none )


checkSaveComplete : Model -> ( Model, Effect Msg )
checkSaveComplete model =
    if model.savesPending <= 0 && model.deletesPending <= 0 then
        ( { model | form = RosterForm.FormHidden, savesPending = 0, deletesPending = 0 }, Effect.none )

    else
        ( model, Effect.none )


handleSaveError : String -> Model -> ( Model, Effect Msg )
handleSaveError err model =
    case model.form of
        RosterForm.FormSavingDraft formData ->
            ( { model
                | form = RosterForm.FormEditing formData [ err ]
                , savesPending = 0
                , deletesPending = 0
              }
            , Effect.none
            )

        RosterForm.FormSubmitting formData ->
            ( { model
                | form = RosterForm.FormEditing formData [ err ]
                , savesPending = 0
                , deletesPending = 0
              }
            , Effect.none
            )

        _ ->
            ( model, Effect.none )



-- HELPERS


entriesForCell : String -> String -> Api.RosterSide -> List RosterEntry -> List RosterEntry
entriesForCell teamId roundId side entries =
    entries
        |> List.filter
            (\e ->
                e.team == teamId && e.round == roundId && e.side == side
            )


submissionForCell : String -> String -> Api.RosterSide -> RemoteData (List RosterSubmission) -> Maybe RosterSubmission
submissionForCell teamId roundId side submissions =
    case submissions of
        Succeeded subs ->
            subs
                |> List.filter
                    (\s ->
                        s.team == teamId && s.round == roundId && s.side == side
                    )
                |> List.head

        _ ->
            Nothing


teamName : Team -> String
teamName team =
    if team.name /= "" then
        team.name

    else
        team.id


studentName : String -> List Student -> String
studentName id students =
    students
        |> List.filter (\s -> s.id == id)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault id


characterNameById : String -> List CaseCharacter -> String
characterNameById id characters =
    characters
        |> List.filter (\c -> c.id == id)
        |> List.head
        |> Maybe.map .characterName
        |> Maybe.withDefault ""


statusBadge : Maybe RosterSubmission -> Html Msg
statusBadge maybeSub =
    case maybeSub of
        Just sub ->
            if sub.submittedAt /= Nothing then
                UI.badge { label = "Submitted", variant = "success" }

            else
                UI.badge { label = "Draft", variant = "warning" }

        Nothing ->
            UI.badge { label = "Missing", variant = "error" }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Rosters"
    , body =
        [ UI.titleBar
            { title = "Rosters"
            , actions = []
            }
        , viewFilters model
        , viewDashboard model
        , viewSelectedCell model
        ]
    }


viewFilters : Model -> Html Msg
viewFilters model =
    UI.filtersRow
        [ UI.filterSelect
            { label = "Tournament:"
            , value = model.filterTournament
            , onInput = FilterTournamentChanged
            , options =
                { value = "", label = "All Tournaments" }
                    :: List.map (\t -> { value = t.id, label = t.name }) model.tournaments
            }
        , case model.rounds of
            Succeeded rounds ->
                let
                    filteredRounds =
                        if model.filterTournament == "" then
                            rounds

                        else
                            List.filter (\r -> r.tournament == model.filterTournament) rounds
                in
                UI.filterSelect
                    { label = "Round:"
                    , value = model.filterRound
                    , onInput = FilterRoundChanged
                    , options =
                        { value = "", label = "All Rounds" }
                            :: List.map
                                (\r ->
                                    { value = r.id
                                    , label = "Round " ++ String.fromInt r.number
                                    }
                                )
                                filteredRounds
                    }

            _ ->
                text ""
        ]


viewDashboard : Model -> Html Msg
viewDashboard model =
    case ( model.teams, model.rounds, model.submissions ) of
        ( Succeeded teams, Succeeded rounds, Succeeded submissions ) ->
            let
                filteredTeams =
                    if model.filterTournament == "" then
                        teams

                    else
                        List.filter (\t -> t.tournament == model.filterTournament) teams

                filteredRounds =
                    if model.filterTournament == "" then
                        rounds

                    else
                        List.filter (\r -> r.tournament == model.filterTournament) rounds

                visibleRounds =
                    if model.filterRound == "" then
                        filteredRounds

                    else
                        List.filter (\r -> r.id == model.filterRound) filteredRounds

                activeTeams =
                    List.filter (\t -> t.status == Api.TeamActive) filteredTeams
            in
            if List.isEmpty activeTeams then
                UI.emptyState "No active teams."

            else if List.isEmpty visibleRounds then
                UI.emptyState "No rounds scheduled."

            else
                viewMatrix activeTeams visibleRounds submissions model.selectedCell

        ( Failed err, _, _ ) ->
            UI.error err

        ( _, Failed err, _ ) ->
            UI.error err

        ( _, _, Failed err ) ->
            UI.error err

        _ ->
            UI.loading


viewMatrix : List Team -> List Round -> List RosterSubmission -> Maybe SelectedCell -> Html Msg
viewMatrix teams rounds submissions selectedCell =
    UI.tableWrap
        (table [ Attr.class "table table-sm table-zebra w-full" ]
            [ thead []
                [ tr []
                    (th [] [ text "Team" ]
                        :: List.concatMap
                            (\r ->
                                [ th [ Attr.class "text-center" ]
                                    [ text ("R" ++ String.fromInt r.number)
                                    , br [] []
                                    , span [ Attr.class "text-xs font-normal" ] [ text "P" ]
                                    ]
                                , th [ Attr.class "text-center" ]
                                    [ text ("R" ++ String.fromInt r.number)
                                    , br [] []
                                    , span [ Attr.class "text-xs font-normal" ] [ text "D" ]
                                    ]
                                ]
                            )
                            rounds
                    )
                ]
            , tbody []
                (List.map (viewTeamRow rounds submissions selectedCell) teams)
            ]
        )


viewTeamRow : List Round -> List RosterSubmission -> Maybe SelectedCell -> Team -> Html Msg
viewTeamRow rounds submissions selectedCell team =
    tr []
        (td [ Attr.class "font-medium" ] [ text (teamName team) ]
            :: List.concatMap
                (\round ->
                    [ viewCellButton team.id round.id Api.Prosecution submissions selectedCell
                    , viewCellButton team.id round.id Api.Defense submissions selectedCell
                    ]
                )
                rounds
        )


viewCellButton : String -> String -> Api.RosterSide -> List RosterSubmission -> Maybe SelectedCell -> Html Msg
viewCellButton teamId roundId side submissions selectedCell =
    let
        maybeSub =
            submissions
                |> List.filter (\s -> s.team == teamId && s.round == roundId && s.side == side)
                |> List.head

        isSelected =
            case selectedCell of
                Just cell ->
                    cell.teamId == teamId && cell.roundId == roundId && cell.side == side

                Nothing ->
                    False
    in
    UI.interactiveCell isSelected (SelectCell teamId roundId side) (statusBadge maybeSub)


viewSelectedCell : Model -> Html Msg
viewSelectedCell model =
    case model.selectedCell of
        Nothing ->
            text ""

        Just cell ->
            let
                cellTeamName =
                    case model.teams of
                        Succeeded teams ->
                            teams
                                |> List.filter (\t -> t.id == cell.teamId)
                                |> List.head
                                |> Maybe.map teamName
                                |> Maybe.withDefault cell.teamId

                        _ ->
                            cell.teamId

                cellRoundNumber =
                    case model.rounds of
                        Succeeded rounds ->
                            rounds
                                |> List.filter (\r -> r.id == cell.roundId)
                                |> List.head
                                |> Maybe.map (\r -> "Round " ++ String.fromInt r.number)
                                |> Maybe.withDefault cell.roundId

                        _ ->
                            cell.roundId

                cellEntries =
                    entriesForCell cell.teamId cell.roundId cell.side model.entries
            in
            UI.card
                [ UI.cardBody
                    [ UI.cardHeader
                        [ UI.cardTitle
                            (cellTeamName
                                ++ " — "
                                ++ cellRoundNumber
                                ++ " — "
                                ++ RosterForm.sideLabel cell.side
                            )
                        , UI.iconButton CloseCell (text "×")
                        ]
                    , case model.form of
                        RosterForm.FormHidden ->
                            viewCellReadOnly cellEntries model

                        RosterForm.FormEditing _ _ ->
                            viewFormCard model

                        RosterForm.FormSavingDraft _ ->
                            viewFormCard model

                        RosterForm.FormSubmitting _ ->
                            viewFormCard model
                    ]
                ]


viewCellReadOnly : List RosterEntry -> Model -> Html Msg
viewCellReadOnly entries model =
    div []
        [ if List.isEmpty entries then
            p [ Attr.class "text-sm text-base-content/50 py-4" ] [ text "No roster entries." ]

          else
            table [ Attr.class "table table-sm table-zebra w-full" ]
                [ thead []
                    [ tr []
                        [ th [] [ text "Student" ]
                        , th [] [ text "Role" ]
                        , th [] [ text "Character" ]
                        ]
                    ]
                , tbody []
                    (List.map (viewReadOnlyRow model) entries)
                ]
        , UI.actionRow
            [ UI.smallButton { label = "Edit Roster", variant = "primary", msg = EditRoster } ]
        ]


viewReadOnlyRow : Model -> RosterEntry -> Html Msg
viewReadOnlyRow model entry =
    tr []
        [ td [] [ text (studentName (Maybe.withDefault "" entry.student) model.students) ]
        , td [] [ text (RosterForm.roleName entry.role) ]
        , td [] [ text (characterNameById (Maybe.withDefault "" entry.character) model.caseCharacters) ]
        ]


viewFormCard : Model -> Html Msg
viewFormCard model =
    let
        config =
            { students = model.students
            , caseCharacters = model.caseCharacters
            , onAddRow = AddRow
            , onRemoveRow = RemoveRow
            , onUpdateStudent = UpdateRowStudent
            , onUpdateEntryType = UpdateRowEntryType
            , onUpdateRole = UpdateRowRole
            , onUpdateCharacter = UpdateRowCharacter
            , onSaveDraft = SaveDraft
            , onSubmitRoster = SubmitRoster
            , onCancel = CancelForm
            }
    in
    RosterForm.viewFormContent config model.form
