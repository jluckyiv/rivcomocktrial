module Pages.Team.Rosters exposing (Model, Msg, page)

import Api
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import RosterForm
import Route exposing (Route)
import Shared
import Shared.Model exposing (CoachAuth(..))
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ shared _ =
    Page.new
        { init = init shared
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Team {})



-- MODEL


type PageState
    = LoadingTeam
    | TeamNotFound
    | LoadFailed String
    | TeamReady TeamData


type alias Model =
    { state : PageState }


type TaskFormState
    = TaskFormHidden
    | TaskFormEditing TaskFormData (List String)
    | TaskFormSaving TaskFormData


type alias TaskFormData =
    { rosterEntryId : String
    , roundId : String
    , side : Api.RosterSide
    , rows : List TaskFormRow
    }


type alias TaskFormRow =
    { id : Maybe String
    , taskType : String
    , character : String
    }


type alias TeamData =
    { team : Api.Team
    , rounds : RemoteData (List Api.Round)
    , trials : List Api.Trial
    , caseCharacters : List Api.CaseCharacter
    , students : List Api.Student
    , entries : List Api.RosterEntry
    , submissions : List Api.RosterSubmission
    , tasks : List Api.AttorneyTask
    , expandedRound : Maybe String
    , form : RosterForm.FormState
    , savesPending : Int
    , deletesPending : Int
    , taskForm : TaskFormState
    , taskSavesPending : Int
    , taskDeletesPending : Int
    }


type RemoteData a
    = Loading
    | Succeeded a
    | Failed String


emptyTeamData : Api.Team -> TeamData
emptyTeamData team =
    { team = team
    , rounds = Loading
    , trials = []
    , caseCharacters = []
    , students = []
    , entries = []
    , submissions = []
    , tasks = []
    , expandedRound = Nothing
    , form = RosterForm.FormHidden
    , savesPending = 0
    , deletesPending = 0
    , taskForm = TaskFormHidden
    , taskSavesPending = 0
    , taskDeletesPending = 0
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared _ =
    let
        coachId =
            case shared.coachAuth of
                LoggedIn creds ->
                    creds.user.id

                NotLoggedIn ->
                    ""
    in
    ( { state = LoadingTeam }
    , Pb.publicList
        { collection = "teams"
        , tag = "my-team"
        , filter = "coach = '" ++ coachId ++ "'"
        , sort = ""
        }
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | ToggleRound String
    | EditRoster String Api.RosterSide
    | CancelRosterForm
    | AddRow
    | RemoveRow Int
    | UpdateRowStudent Int String
    | UpdateRowEntryType Int String
    | UpdateRowRole Int String
    | UpdateRowCharacter Int String
    | SaveDraft
    | SubmitRoster
    | EditTasks String String Api.RosterSide
    | CancelTaskForm
    | AddTaskRow
    | RemoveTaskRow Int
    | UpdateTaskType Int String
    | UpdateTaskCharacter Int String
    | SaveTasks


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case model.state of
        TeamReady data ->
            let
                ( newData, effect ) =
                    updateTeamData msg data
            in
            ( { model | state = TeamReady newData }, effect )

        _ ->
            case msg of
                PbMsg value ->
                    handleInitialPbMsg value model

                _ ->
                    ( model, Effect.none )


handleInitialPbMsg : Json.Decode.Value -> Model -> ( Model, Effect Msg )
handleInitialPbMsg value model =
    case Pb.responseTag value of
        Just "my-team" ->
            case Pb.decodeList Api.teamDecoder value of
                Ok (team :: _) ->
                    let
                        data =
                            emptyTeamData team

                        teamId =
                            team.id

                        tournamentId =
                            team.tournament
                    in
                    ( { model | state = TeamReady data }
                    , Effect.batch
                        [ Pb.publicList
                            { collection = "rounds"
                            , tag = "rounds"
                            , filter = "tournament = '" ++ tournamentId ++ "'"
                            , sort = "number"
                            }
                        , Pb.publicList
                            { collection = "trials"
                            , tag = "trials"
                            , filter = "prosecution_team = '" ++ teamId ++ "' || defense_team = '" ++ teamId ++ "'"
                            , sort = ""
                            }
                        , Pb.publicList
                            { collection = "case_characters"
                            , tag = "case-characters"
                            , filter = "tournament = '" ++ tournamentId ++ "'"
                            , sort = "side,sort_order"
                            }
                        , Pb.publicList
                            { collection = "students"
                            , tag = "students"
                            , filter = "school = '" ++ team.school ++ "'"
                            , sort = "name"
                            }
                        , Pb.publicList
                            { collection = "roster_entries"
                            , tag = "roster-entries"
                            , filter = "team = '" ++ teamId ++ "'"
                            , sort = "side,sort_order"
                            }
                        , Pb.publicList
                            { collection = "roster_submissions"
                            , tag = "roster-submissions"
                            , filter = "team = '" ++ teamId ++ "'"
                            , sort = ""
                            }
                        , Pb.publicList
                            { collection = "attorney_tasks"
                            , tag = "attorney-tasks"
                            , filter = "roster_entry.team = '" ++ teamId ++ "'"
                            , sort = "sort_order"
                            }
                        ]
                    )

                Ok [] ->
                    ( { model | state = TeamNotFound }, Effect.none )

                Err _ ->
                    ( { model | state = LoadFailed "Failed to load team." }
                    , Effect.none
                    )

        _ ->
            ( model, Effect.none )


updateTeamData : Msg -> TeamData -> ( TeamData, Effect Msg )
updateTeamData msg data =
    case msg of
        PbMsg value ->
            handleTeamPbMsg value data

        ToggleRound roundId ->
            let
                newExpanded =
                    if data.expandedRound == Just roundId then
                        Nothing

                    else
                        Just roundId
            in
            ( { data | expandedRound = newExpanded }, Effect.none )

        EditRoster roundId side ->
            case data.taskForm of
                TaskFormHidden ->
                    let
                        existingEntries =
                            entriesForRound roundId side data.entries

                        rows =
                            if List.isEmpty existingEntries then
                                [ RosterForm.emptyRow ]

                            else
                                List.map RosterForm.entryToFormRow existingEntries
                    in
                    ( { data
                        | form =
                            RosterForm.FormEditing
                                { teamId = data.team.id
                                , roundId = roundId
                                , side = side
                                , rows = rows
                                }
                                []
                        , expandedRound = Just roundId
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        CancelRosterForm ->
            ( { data | form = RosterForm.FormHidden }, Effect.none )

        AddRow ->
            ( { data | form = RosterForm.updateFormRows (\rows -> rows ++ [ RosterForm.emptyRow ]) data.form }
            , Effect.none
            )

        RemoveRow idx ->
            ( { data
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
                        data.form
              }
            , Effect.none
            )

        UpdateRowStudent idx val ->
            ( { data | form = RosterForm.updateRow idx (\r -> { r | student = val }) data.form }, Effect.none )

        UpdateRowEntryType idx val ->
            ( { data | form = RosterForm.updateRowEntryType idx val data.form }, Effect.none )

        UpdateRowRole idx val ->
            ( { data | form = RosterForm.updateRowRole idx val data.form }, Effect.none )

        UpdateRowCharacter idx val ->
            ( { data | form = RosterForm.updateRow idx (\r -> { r | character = val }) data.form }, Effect.none )

        SaveDraft ->
            handleSave False data

        SubmitRoster ->
            handleSave True data

        EditTasks entryId roundId side ->
            case data.form of
                RosterForm.FormHidden ->
                    let
                        existingTasks =
                            tasksForEntry entryId data.tasks

                        rows =
                            if List.isEmpty existingTasks then
                                [ emptyTaskRow ]

                            else
                                List.map taskToFormRow existingTasks
                    in
                    ( { data
                        | taskForm =
                            TaskFormEditing
                                { rosterEntryId = entryId
                                , roundId = roundId
                                , side = side
                                , rows = rows
                                }
                                []
                        , expandedRound = Just roundId
                      }
                    , Effect.none
                    )

                _ ->
                    ( data, Effect.none )

        CancelTaskForm ->
            ( { data | taskForm = TaskFormHidden }, Effect.none )

        AddTaskRow ->
            ( { data | taskForm = updateTaskFormRows (\rows -> rows ++ [ emptyTaskRow ]) data.taskForm }
            , Effect.none
            )

        RemoveTaskRow idx ->
            ( { data
                | taskForm =
                    updateTaskFormRows
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
                        data.taskForm
              }
            , Effect.none
            )

        UpdateTaskType idx val ->
            let
                clearCharIfNeeded r =
                    if val == "opening" || val == "closing" then
                        { r | taskType = val, character = "" }

                    else
                        { r | taskType = val }
            in
            ( { data | taskForm = updateTaskRow idx clearCharIfNeeded data.taskForm }
            , Effect.none
            )

        UpdateTaskCharacter idx val ->
            ( { data | taskForm = updateTaskRow idx (\r -> { r | character = val }) data.taskForm }
            , Effect.none
            )

        SaveTasks ->
            handleSaveTasks data


handleSave : Bool -> TeamData -> ( TeamData, Effect Msg )
handleSave submitting data =
    case data.form of
        RosterForm.FormEditing formData _ ->
            case RosterForm.validateForm formData of
                Err errors ->
                    ( { data | form = RosterForm.FormEditing formData errors }, Effect.none )

                Ok validRows ->
                    let
                        teamId =
                            formData.teamId

                        roundId =
                            formData.roundId

                        side =
                            formData.side

                        existingEntries =
                            entriesForRound roundId side data.entries

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
                                { team = teamId
                                , round = roundId
                                , side = side
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
                                    Pb.publicCreate
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
                                                Pb.publicUpdate
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
                                    Pb.publicDelete
                                        { collection = "roster_entries"
                                        , id = entry.id
                                        , tag = "delete-entry"
                                        }
                                )
                                toDelete

                        submissionEffect =
                            let
                                existingSub =
                                    submissionForRound roundId side data.submissions

                                submittedAt =
                                    if submitting then
                                        Just "now"

                                    else
                                        Nothing

                                body =
                                    Api.encodeRosterSubmission
                                        { team = teamId
                                        , round = roundId
                                        , side = side
                                        , submittedAt = submittedAt
                                        }
                            in
                            case existingSub of
                                Just sub ->
                                    [ Pb.publicUpdate
                                        { collection = "roster_submissions"
                                        , id = sub.id
                                        , tag = "save-submission"
                                        , body = body
                                        }
                                    ]

                                Nothing ->
                                    [ Pb.publicCreate
                                        { collection = "roster_submissions"
                                        , tag = "save-submission"
                                        , body = body
                                        }
                                    ]

                        allEffects =
                            createEffects ++ updateEffects ++ deleteEffects ++ submissionEffect
                    in
                    ( { data
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
            ( data, Effect.none )


handleTeamPbMsg : Json.Decode.Value -> TeamData -> ( TeamData, Effect Msg )
handleTeamPbMsg value data =
    case Pb.responseTag value of
        Just "rounds" ->
            case Pb.decodeList Api.roundDecoder value of
                Ok items ->
                    ( { data | rounds = Succeeded items }, Effect.none )

                Err _ ->
                    ( { data | rounds = Failed "Failed to load rounds." }, Effect.none )

        Just "trials" ->
            case Pb.decodeList Api.trialDecoder value of
                Ok items ->
                    ( { data | trials = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "case-characters" ->
            case Pb.decodeList Api.caseCharacterDecoder value of
                Ok items ->
                    ( { data | caseCharacters = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "students" ->
            case Pb.decodeList Api.studentDecoder value of
                Ok items ->
                    ( { data | students = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "roster-entries" ->
            case Pb.decodeList Api.rosterEntryDecoder value of
                Ok items ->
                    ( { data | entries = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "roster-submissions" ->
            case Pb.decodeList Api.rosterSubmissionDecoder value of
                Ok items ->
                    ( { data | submissions = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "attorney-tasks" ->
            case Pb.decodeList Api.attorneyTaskDecoder value of
                Ok items ->
                    ( { data | tasks = items }, Effect.none )

                Err _ ->
                    ( data, Effect.none )

        Just "save-entry" ->
            case Pb.decodeRecord Api.rosterEntryDecoder value of
                Ok entry ->
                    let
                        updatedEntries =
                            if List.any (\e -> e.id == entry.id) data.entries then
                                List.map
                                    (\e ->
                                        if e.id == entry.id then
                                            entry

                                        else
                                            e
                                    )
                                    data.entries

                            else
                                data.entries ++ [ entry ]

                        newPending =
                            data.savesPending - 1
                    in
                    checkSaveComplete
                        { data
                            | entries = updatedEntries
                            , savesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to save roster entry." data

        Just "delete-entry" ->
            case Pb.decodeDelete value of
                Ok id ->
                    let
                        newPending =
                            data.deletesPending - 1
                    in
                    checkSaveComplete
                        { data
                            | entries = List.filter (\e -> e.id /= id) data.entries
                            , deletesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to delete roster entry." data

        Just "save-submission" ->
            case Pb.decodeRecord Api.rosterSubmissionDecoder value of
                Ok sub ->
                    let
                        updatedSubs =
                            if List.any (\s -> s.id == sub.id) data.submissions then
                                List.map
                                    (\s ->
                                        if s.id == sub.id then
                                            sub

                                        else
                                            s
                                    )
                                    data.submissions

                            else
                                data.submissions ++ [ sub ]

                        newPending =
                            data.savesPending - 1
                    in
                    checkSaveComplete
                        { data
                            | submissions = updatedSubs
                            , savesPending = newPending
                        }

                Err _ ->
                    handleSaveError "Failed to save submission." data

        Just "save-task" ->
            case Pb.decodeRecord Api.attorneyTaskDecoder value of
                Ok task ->
                    let
                        updatedTasks =
                            if List.any (\t -> t.id == task.id) data.tasks then
                                List.map
                                    (\t ->
                                        if t.id == task.id then
                                            task

                                        else
                                            t
                                    )
                                    data.tasks

                            else
                                data.tasks ++ [ task ]

                        newPending =
                            data.taskSavesPending - 1
                    in
                    checkTaskSaveComplete
                        { data
                            | tasks = updatedTasks
                            , taskSavesPending = newPending
                        }

                Err _ ->
                    handleTaskSaveError "Failed to save task." data

        Just "delete-task" ->
            case Pb.decodeDelete value of
                Ok id ->
                    let
                        newPending =
                            data.taskDeletesPending - 1
                    in
                    checkTaskSaveComplete
                        { data
                            | tasks = List.filter (\t -> t.id /= id) data.tasks
                            , taskDeletesPending = newPending
                        }

                Err _ ->
                    handleTaskSaveError "Failed to delete task." data

        _ ->
            ( data, Effect.none )


checkSaveComplete : TeamData -> ( TeamData, Effect Msg )
checkSaveComplete data =
    if data.savesPending <= 0 && data.deletesPending <= 0 then
        ( { data | form = RosterForm.FormHidden, savesPending = 0, deletesPending = 0 }, Effect.none )

    else
        ( data, Effect.none )


handleSaveError : String -> TeamData -> ( TeamData, Effect Msg )
handleSaveError err data =
    case data.form of
        RosterForm.FormSavingDraft formData ->
            ( { data
                | form = RosterForm.FormEditing formData [ err ]
                , savesPending = 0
                , deletesPending = 0
              }
            , Effect.none
            )

        RosterForm.FormSubmitting formData ->
            ( { data
                | form = RosterForm.FormEditing formData [ err ]
                , savesPending = 0
                , deletesPending = 0
              }
            , Effect.none
            )

        _ ->
            ( data, Effect.none )


handleSaveTasks : TeamData -> ( TeamData, Effect Msg )
handleSaveTasks data =
    case data.taskForm of
        TaskFormEditing taskFormData _ ->
            case validateTasks taskFormData of
                Err errors ->
                    ( { data | taskForm = TaskFormEditing taskFormData errors }, Effect.none )

                Ok validRows ->
                    let
                        entryId =
                            taskFormData.rosterEntryId

                        existingTasks =
                            tasksForEntry entryId data.tasks

                        existingIds =
                            List.filterMap .id validRows

                        toDelete =
                            List.filter
                                (\t -> not (List.member t.id existingIds))
                                existingTasks

                        toCreate =
                            List.filter (\r -> r.id == Nothing) validRows

                        toUpdate =
                            List.filter (\r -> r.id /= Nothing) validRows

                        encodeRow idx row =
                            Api.encodeAttorneyTask
                                { rosterEntry = entryId
                                , taskType = parseTaskType row.taskType
                                , character =
                                    if row.character == "" then
                                        Nothing

                                    else
                                        Just row.character
                                , sortOrder = idx
                                }

                        createEffects =
                            List.indexedMap
                                (\idx row ->
                                    Pb.publicCreate
                                        { collection = "attorney_tasks"
                                        , tag = "save-task"
                                        , body = encodeRow idx row
                                        }
                                )
                                toCreate

                        updateEffects =
                            List.indexedMap
                                (\idx row ->
                                    row.id
                                        |> Maybe.map
                                            (\id ->
                                                Pb.publicUpdate
                                                    { collection = "attorney_tasks"
                                                    , id = id
                                                    , tag = "save-task"
                                                    , body = encodeRow idx row
                                                    }
                                            )
                                )
                                toUpdate
                                |> List.filterMap identity

                        deleteEffects =
                            List.map
                                (\task ->
                                    Pb.publicDelete
                                        { collection = "attorney_tasks"
                                        , id = task.id
                                        , tag = "delete-task"
                                        }
                                )
                                toDelete

                        allEffects =
                            createEffects ++ updateEffects ++ deleteEffects
                    in
                    ( { data
                        | taskForm = TaskFormSaving taskFormData
                        , taskSavesPending = List.length createEffects + List.length updateEffects
                        , taskDeletesPending = List.length deleteEffects
                      }
                    , Effect.batch allEffects
                    )

        _ ->
            ( data, Effect.none )


checkTaskSaveComplete : TeamData -> ( TeamData, Effect Msg )
checkTaskSaveComplete data =
    if data.taskSavesPending <= 0 && data.taskDeletesPending <= 0 then
        ( { data | taskForm = TaskFormHidden, taskSavesPending = 0, taskDeletesPending = 0 }, Effect.none )

    else
        ( data, Effect.none )


handleTaskSaveError : String -> TeamData -> ( TeamData, Effect Msg )
handleTaskSaveError err data =
    case data.taskForm of
        TaskFormSaving taskFormData ->
            ( { data
                | taskForm = TaskFormEditing taskFormData [ err ]
                , taskSavesPending = 0
                , taskDeletesPending = 0
              }
            , Effect.none
            )

        _ ->
            ( data, Effect.none )



-- HELPERS


teamSideForRound : Api.Team -> List Api.Trial -> Api.Round -> Maybe Api.RosterSide
teamSideForRound team trials round =
    trials
        |> List.filter (\t -> t.round == round.id)
        |> List.head
        |> Maybe.andThen
            (\trial ->
                if trial.prosecutionTeam == team.id then
                    Just Api.Prosecution

                else if trial.defenseTeam == team.id then
                    Just Api.Defense

                else
                    Nothing
            )


submissionForRound : String -> Api.RosterSide -> List Api.RosterSubmission -> Maybe Api.RosterSubmission
submissionForRound roundId side submissions =
    submissions
        |> List.filter
            (\s ->
                s.round == roundId && s.side == side
            )
        |> List.head


entriesForRound : String -> Api.RosterSide -> List Api.RosterEntry -> List Api.RosterEntry
entriesForRound roundId side entries =
    entries
        |> List.filter
            (\e ->
                e.round == roundId && e.side == side
            )


studentName : List Api.Student -> Maybe String -> String
studentName students maybeId =
    case maybeId of
        Nothing ->
            "—"

        Just id ->
            students
                |> List.filter (\s -> s.id == id)
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault id


characterName : List Api.CaseCharacter -> Maybe String -> String
characterName characters maybeId =
    case maybeId of
        Nothing ->
            ""

        Just id ->
            characters
                |> List.filter (\c -> c.id == id)
                |> List.head
                |> Maybe.map .characterName
                |> Maybe.withDefault ""


sideVariant : Api.RosterSide -> String
sideVariant side =
    case side of
        Api.Prosecution ->
            "info"

        Api.Defense ->
            "warning"


submissionStatus : Maybe Api.RosterSubmission -> List Api.RosterEntry -> { label : String, variant : String }
submissionStatus maybeSub entries =
    case maybeSub of
        Just sub ->
            if sub.submittedAt /= Nothing then
                { label = "Submitted", variant = "success" }

            else
                { label = "Draft", variant = "warning" }

        Nothing ->
            if List.isEmpty entries then
                { label = "Not Started", variant = "neutral" }

            else
                { label = "Draft", variant = "warning" }


isSubmitted : Maybe Api.RosterSubmission -> Bool
isSubmitted maybeSub =
    case maybeSub of
        Just sub ->
            sub.submittedAt /= Nothing

        Nothing ->
            False


tasksForEntry : String -> List Api.AttorneyTask -> List Api.AttorneyTask
tasksForEntry entryId tasks =
    tasks
        |> List.filter (\t -> t.rosterEntry == entryId)
        |> List.sortBy .sortOrder


taskTypeName : Api.TaskType -> String
taskTypeName tt =
    case tt of
        Api.OpeningTask ->
            "Opening"

        Api.DirectTask ->
            "Direct"

        Api.CrossTask ->
            "Cross"

        Api.ClosingTask ->
            "Closing"


emptyTaskRow : TaskFormRow
emptyTaskRow =
    { id = Nothing
    , taskType = ""
    , character = ""
    }


taskToFormRow : Api.AttorneyTask -> TaskFormRow
taskToFormRow task =
    { id = Just task.id
    , taskType = taskTypeToString task.taskType
    , character = Maybe.withDefault "" task.character
    }


taskTypeToString : Api.TaskType -> String
taskTypeToString tt =
    case tt of
        Api.OpeningTask ->
            "opening"

        Api.DirectTask ->
            "direct"

        Api.CrossTask ->
            "cross"

        Api.ClosingTask ->
            "closing"


parseTaskType : String -> Api.TaskType
parseTaskType s =
    case s of
        "direct" ->
            Api.DirectTask

        "cross" ->
            Api.CrossTask

        "closing" ->
            Api.ClosingTask

        _ ->
            Api.OpeningTask


updateTaskFormRows : (List TaskFormRow -> List TaskFormRow) -> TaskFormState -> TaskFormState
updateTaskFormRows transform state =
    case state of
        TaskFormEditing taskFormData _ ->
            TaskFormEditing { taskFormData | rows = transform taskFormData.rows } []

        _ ->
            state


updateTaskRow : Int -> (TaskFormRow -> TaskFormRow) -> TaskFormState -> TaskFormState
updateTaskRow idx transform state =
    updateTaskFormRows
        (List.indexedMap
            (\i r ->
                if i == idx then
                    transform r

                else
                    r
            )
        )
        state


validateTasks : TaskFormData -> Result (List String) (List TaskFormRow)
validateTasks taskFormData =
    let
        nonEmptyRows =
            List.filter (\r -> r.taskType /= "") taskFormData.rows

        rowErrors =
            nonEmptyRows
                |> List.indexedMap
                    (\i r ->
                        []
                            |> addTaskErrorIf (r.taskType == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": task type is required.")
                            |> addTaskErrorIf
                                ((r.taskType == "direct" || r.taskType == "cross") && r.character == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": character is required for direct/cross.")
                    )
                |> List.concat

        duplicateErrors =
            let
                keys =
                    List.map (\r -> ( r.taskType, r.character )) nonEmptyRows

                hasDups =
                    List.length keys /= List.length (uniquePairs keys)
            in
            if hasDups then
                [ "Duplicate tasks are not allowed." ]

            else
                []
    in
    if List.isEmpty nonEmptyRows then
        Err [ "Add at least one task." ]

    else if List.isEmpty rowErrors && List.isEmpty duplicateErrors then
        Ok nonEmptyRows

    else
        Err (rowErrors ++ duplicateErrors)


addTaskErrorIf : Bool -> String -> List String -> List String
addTaskErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors


uniquePairs : List ( String, String ) -> List ( String, String )
uniquePairs list =
    List.foldl
        (\item acc ->
            if List.member item acc then
                acc

            else
                acc ++ [ item ]
        )
        []
        list



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
        , viewContent model
        ]
    }


viewContent : Model -> Html Msg
viewContent model =
    case model.state of
        LoadingTeam ->
            UI.loading

        TeamNotFound ->
            UI.error "No team found. Please contact your administrator."

        LoadFailed err ->
            UI.error err

        TeamReady data ->
            viewTeamData data


viewTeamData : TeamData -> Html Msg
viewTeamData data =
    case data.rounds of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded rounds ->
            if List.isEmpty rounds then
                UI.emptyState "No rounds scheduled yet."

            else
                div [ Attr.class "space-y-2" ]
                    (List.map (viewRoundRow data) rounds)


viewRoundRow : TeamData -> Api.Round -> Html Msg
viewRoundRow data round =
    let
        maybeSide =
            teamSideForRound data.team data.trials round

        isExpanded =
            data.expandedRound == Just round.id
    in
    case maybeSide of
        Nothing ->
            div [ Attr.class "collapse collapse-arrow bg-base-200" ]
                [ div [ Attr.class "collapse-title font-medium flex items-center gap-3" ]
                    [ text ("Round " ++ String.fromInt round.number)
                    , span [ Attr.class "text-sm text-base-content/50" ] [ text "No assignment" ]
                    ]
                ]

        Just side ->
            let
                roundEntries =
                    entriesForRound round.id side data.entries

                maybeSub =
                    submissionForRound round.id side data.submissions

                status =
                    submissionStatus maybeSub roundEntries

                isEditingThisRound =
                    case data.form of
                        RosterForm.FormEditing fd _ ->
                            fd.roundId == round.id

                        RosterForm.FormSavingDraft fd ->
                            fd.roundId == round.id

                        RosterForm.FormSubmitting fd ->
                            fd.roundId == round.id

                        RosterForm.FormHidden ->
                            False
            in
            div
                [ Attr.class "collapse collapse-arrow bg-base-200"
                , Attr.classList [ ( "collapse-open", isExpanded ) ]
                ]
                [ div
                    [ Attr.class "collapse-title font-medium cursor-pointer flex items-center gap-3"
                    , Events.onClick (ToggleRound round.id)
                    ]
                    [ text ("Round " ++ String.fromInt round.number)
                    , if round.date /= "" then
                        span [ Attr.class "text-sm text-base-content/60" ] [ text round.date ]

                      else
                        text ""
                    , UI.badge { label = RosterForm.sideLabel side, variant = sideVariant side }
                    , UI.badge { label = status.label, variant = status.variant }
                    ]
                , if isExpanded then
                    div [ Attr.class "collapse-content" ]
                        [ if isEditingThisRound then
                            viewRosterForm data

                          else
                            viewRosterReadOnly data roundEntries side maybeSub round.id
                        ]

                  else
                    text ""
                ]


viewRosterReadOnly : TeamData -> List Api.RosterEntry -> Api.RosterSide -> Maybe Api.RosterSubmission -> String -> Html Msg
viewRosterReadOnly data entries side maybeSub roundId =
    div []
        [ viewRosterEntries data entries
        , viewTaskFormSection data
        , if not (isSubmitted maybeSub) then
            div [ Attr.class "mt-4" ]
                [ button
                    [ Attr.class "btn btn-primary btn-sm"
                    , Events.onClick (EditRoster roundId side)
                    ]
                    [ text "Edit Roster" ]
                ]

          else
            text ""
        ]


viewRosterEntries : TeamData -> List Api.RosterEntry -> Html Msg
viewRosterEntries data entries =
    if List.isEmpty entries then
        p [ Attr.class "text-sm text-base-content/50 py-4" ]
            [ text "No roster entries yet." ]

    else
        let
            active =
                List.filter (\e -> e.entryType == Api.ActiveEntry) entries

            substitutes =
                List.filter (\e -> e.entryType == Api.SubstituteEntry) entries

            nonActive =
                List.filter (\e -> e.entryType == Api.NonActiveEntry) entries
        in
        div [ Attr.class "space-y-4 py-2" ]
            [ if List.isEmpty active then
                text ""

              else
                viewEntryGroup data "Active Members" active
            , if List.isEmpty substitutes then
                text ""

              else
                viewEntryGroup data "Substitutes" substitutes
            , if List.isEmpty nonActive then
                text ""

              else
                viewEntryGroup data "Non-Active Members" nonActive
            ]


viewEntryGroup : TeamData -> String -> List Api.RosterEntry -> Html Msg
viewEntryGroup data groupLabel entries =
    div []
        [ h4 [ Attr.class "font-semibold text-sm mb-1" ] [ text groupLabel ]
        , table [ Attr.class "table table-sm table-zebra w-full" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Student" ]
                    , th [] [ text "Role" ]
                    , th [] [ text "Character" ]
                    , th [] [ text "Tasks" ]
                    ]
                ]
            , tbody []
                (List.map (viewEntryRow data) entries)
            ]
        ]


viewEntryRow : TeamData -> Api.RosterEntry -> Html Msg
viewEntryRow data entry =
    let
        entryTasks =
            tasksForEntry entry.id data.tasks

        isTrialAttorney =
            entry.role == Just Api.TrialAttorneyRole

        isTaskFormOpenForThisEntry =
            case data.taskForm of
                TaskFormEditing taskFormData _ ->
                    taskFormData.rosterEntryId == entry.id

                TaskFormSaving taskFormData ->
                    taskFormData.rosterEntryId == entry.id

                TaskFormHidden ->
                    False

        isAnyFormOpen =
            data.form /= RosterForm.FormHidden || data.taskForm /= TaskFormHidden
    in
    tr []
        [ td [] [ text (studentName data.students entry.student) ]
        , td [] [ text (RosterForm.roleName entry.role) ]
        , td [] [ text (characterName data.caseCharacters entry.character) ]
        , td []
            [ div [ Attr.class "flex flex-wrap items-center gap-1" ]
                (List.map viewTaskBadge entryTasks
                    ++ (if isTrialAttorney && not isAnyFormOpen then
                            [ button
                                [ Attr.class "btn btn-ghost btn-xs"
                                , Events.onClick (EditTasks entry.id entry.round entry.side)
                                ]
                                [ text "Edit Tasks" ]
                            ]

                        else if isTrialAttorney && isTaskFormOpenForThisEntry then
                            [ span [ Attr.class "text-sm text-base-content/50" ] [ text "editing..." ] ]

                        else
                            []
                       )
                )
            ]
        ]


viewTaskBadge : Api.AttorneyTask -> Html Msg
viewTaskBadge task =
    span [ Attr.class "badge badge-ghost badge-sm" ]
        [ text (taskTypeName task.taskType) ]


viewTaskFormSection : TeamData -> Html Msg
viewTaskFormSection data =
    case data.taskForm of
        TaskFormHidden ->
            text ""

        TaskFormEditing taskFormData errors ->
            viewTaskFormContent data taskFormData errors False

        TaskFormSaving taskFormData ->
            viewTaskFormContent data taskFormData [] True


viewTaskFormContent : TeamData -> TaskFormData -> List String -> Bool -> Html Msg
viewTaskFormContent data taskFormData errors saving =
    let
        attorneyName =
            data.entries
                |> List.filter (\e -> e.id == taskFormData.rosterEntryId)
                |> List.head
                |> Maybe.map (\e -> studentName data.students e.student)
                |> Maybe.withDefault "Trial Attorney"

        ownSideChars =
            data.caseCharacters
                |> List.filter (\c -> c.side == taskFormData.side)

        opposingSide =
            case taskFormData.side of
                Api.Prosecution ->
                    Api.Defense

                Api.Defense ->
                    Api.Prosecution

        opposingChars =
            data.caseCharacters
                |> List.filter (\c -> c.side == opposingSide)
    in
    div [ Attr.class "mt-4 p-4 bg-base-200 rounded-lg" ]
        [ h4 [ Attr.class "font-semibold mb-2" ]
            [ text ("Task Assignments — " ++ attorneyName) ]
        , UI.errorList errors
        , table [ Attr.class "table table-sm w-full" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Task" ]
                    , th [] [ text "Character" ]
                    , th [] []
                    ]
                ]
            , tbody []
                (List.indexedMap
                    (viewTaskFormRow ownSideChars opposingChars saving)
                    taskFormData.rows
                )
            ]
        , div [ Attr.class "flex gap-2 mt-3" ]
            [ button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick AddTaskRow
                , Attr.disabled saving
                ]
                [ text "+ Add Task" ]
            ]
        , div [ Attr.class "flex gap-2 mt-3" ]
            [ button
                [ Attr.class "btn btn-primary btn-sm"
                , Events.onClick SaveTasks
                , Attr.disabled saving
                ]
                (if saving then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Saving..."
                    ]

                 else
                    [ text "Save Tasks" ]
                )
            , button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick CancelTaskForm
                , Attr.disabled saving
                ]
                [ text "Cancel" ]
            ]
        ]


viewTaskFormRow :
    List Api.CaseCharacter
    -> List Api.CaseCharacter
    -> Bool
    -> Int
    -> TaskFormRow
    -> Html Msg
viewTaskFormRow ownSideChars opposingChars saving idx row =
    let
        taskTypeOptions =
            [ { value = "", label = "Select task..." }
            , { value = "opening", label = "Opening Statement" }
            , { value = "direct", label = "Direct Examination" }
            , { value = "cross", label = "Cross Examination" }
            , { value = "closing", label = "Closing Argument" }
            ]

        characterOptions =
            case row.taskType of
                "direct" ->
                    { value = "", label = "Select witness..." }
                        :: List.map (\c -> { value = c.id, label = c.characterName }) ownSideChars

                "cross" ->
                    { value = "", label = "Select witness..." }
                        :: List.map (\c -> { value = c.id, label = c.characterName }) opposingChars

                _ ->
                    []
    in
    tr []
        [ td []
            [ select
                [ Attr.class "select select-sm select-bordered"
                , Events.onInput (UpdateTaskType idx)
                , Attr.value row.taskType
                , Attr.disabled saving
                ]
                (List.map
                    (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.taskType) ] [ text o.label ])
                    taskTypeOptions
                )
            ]
        , td []
            [ if row.taskType == "direct" || row.taskType == "cross" then
                select
                    [ Attr.class "select select-sm select-bordered"
                    , Events.onInput (UpdateTaskCharacter idx)
                    , Attr.value row.character
                    , Attr.disabled saving
                    ]
                    (List.map
                        (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.character) ] [ text o.label ])
                        characterOptions
                    )

              else
                text "—"
            ]
        , td []
            [ button
                [ Attr.class "btn btn-ghost btn-sm btn-square text-error"
                , Events.onClick (RemoveTaskRow idx)
                , Attr.disabled saving
                ]
                [ text "×" ]
            ]
        ]



-- FORM VIEW


viewRosterForm : TeamData -> Html Msg
viewRosterForm data =
    let
        config =
            { students = data.students
            , caseCharacters = data.caseCharacters
            , onAddRow = AddRow
            , onRemoveRow = RemoveRow
            , onUpdateStudent = UpdateRowStudent
            , onUpdateEntryType = UpdateRowEntryType
            , onUpdateRole = UpdateRowRole
            , onUpdateCharacter = UpdateRowCharacter
            , onSaveDraft = SaveDraft
            , onSubmitRoster = SubmitRoster
            , onCancel = CancelRosterForm
            }
    in
    RosterForm.viewFormContent config data.form
