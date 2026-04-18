module Pages.Team.Rosters exposing (Model, Msg, page)

import Api
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Json.Encode
import Layouts
import Page exposing (Page)
import Pb
import Route exposing (Route)
import Shared
import Shared.Model exposing (CoachAuth(..))
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
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
    , form : FormState
    , savesPending : Int
    , deletesPending : Int
    }


type RemoteData a
    = Loading
    | Succeeded a
    | Failed String


type FormState
    = FormHidden
    | FormEditing FormData (List String)
    | FormSaving FormData


type alias FormData =
    { roundId : String
    , side : Api.RosterSide
    , rows : List FormRow
    , submitting : Bool
    }


type alias FormRow =
    { id : Maybe String
    , student : String
    , entryType : String
    , role : String
    , character : String
    }


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
    , form = FormHidden
    , savesPending = 0
    , deletesPending = 0
    }


emptyRow : FormRow
emptyRow =
    { id = Nothing
    , student = ""
    , entryType = "active"
    , role = ""
    , character = ""
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
                            , filter = ""
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
                            , filter = ""
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
            let
                existingEntries =
                    entriesForRound roundId side data.entries

                rows =
                    if List.isEmpty existingEntries then
                        [ emptyRow ]

                    else
                        List.map entryToFormRow existingEntries
            in
            ( { data
                | form =
                    FormEditing
                        { roundId = roundId
                        , side = side
                        , rows = rows
                        , submitting = False
                        }
                        []
                , expandedRound = Just roundId
              }
            , Effect.none
            )

        CancelRosterForm ->
            ( { data | form = FormHidden }, Effect.none )

        AddRow ->
            ( { data | form = updateFormRows (\rows -> rows ++ [ emptyRow ]) data.form }
            , Effect.none
            )

        RemoveRow idx ->
            ( { data
                | form =
                    updateFormRows
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
            ( { data | form = updateRow idx (\r -> { r | student = val }) data.form }, Effect.none )

        UpdateRowEntryType idx val ->
            ( { data | form = updateRow idx (\r -> { r | entryType = val, role = "", character = "" }) data.form }, Effect.none )

        UpdateRowRole idx val ->
            let
                clearCharacter r =
                    if val /= "witness" then
                        { r | role = val, character = "" }

                    else
                        { r | role = val }
            in
            ( { data | form = updateRow idx clearCharacter data.form }, Effect.none )

        UpdateRowCharacter idx val ->
            ( { data | form = updateRow idx (\r -> { r | character = val }) data.form }, Effect.none )

        SaveDraft ->
            handleSave False data

        SubmitRoster ->
            handleSave True data


handleSave : Bool -> TeamData -> ( TeamData, Effect Msg )
handleSave submitting data =
    case data.form of
        FormEditing formData _ ->
            case validateForm formData of
                Err errors ->
                    ( { data | form = FormEditing formData errors }, Effect.none )

                Ok validRows ->
                    let
                        teamId =
                            data.team.id

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
                                , entryType = parseEntryType row.entryType
                                , role = parseRole row.role
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

                        savingFormData =
                            { formData | submitting = submitting }
                    in
                    ( { data
                        | form = FormSaving savingFormData
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

        _ ->
            ( data, Effect.none )


checkSaveComplete : TeamData -> ( TeamData, Effect Msg )
checkSaveComplete data =
    if data.savesPending <= 0 && data.deletesPending <= 0 then
        ( { data | form = FormHidden, savesPending = 0, deletesPending = 0 }, Effect.none )

    else
        ( data, Effect.none )


handleSaveError : String -> TeamData -> ( TeamData, Effect Msg )
handleSaveError err data =
    case data.form of
        FormSaving formData ->
            ( { data
                | form = FormEditing formData [ err ]
                , savesPending = 0
                , deletesPending = 0
              }
            , Effect.none
            )

        _ ->
            ( data, Effect.none )



-- HELPERS


entryToFormRow : Api.RosterEntry -> FormRow
entryToFormRow entry =
    { id = Just entry.id
    , student = Maybe.withDefault "" entry.student
    , entryType = entryTypeToString entry.entryType
    , role = roleToString entry.role
    , character = Maybe.withDefault "" entry.character
    }


entryTypeToString : Api.EntryType -> String
entryTypeToString et =
    case et of
        Api.ActiveEntry ->
            "active"

        Api.SubstituteEntry ->
            "substitute"

        Api.NonActiveEntry ->
            "non_active"


roleToString : Maybe Api.RosterRole -> String
roleToString maybeRole =
    case maybeRole of
        Nothing ->
            ""

        Just Api.PretrialAttorneyRole ->
            "pretrial_attorney"

        Just Api.TrialAttorneyRole ->
            "trial_attorney"

        Just Api.WitnessRole ->
            "witness"

        Just Api.ClerkRole ->
            "clerk"

        Just Api.BailiffRole ->
            "bailiff"

        Just Api.ArtistRole ->
            "artist"

        Just Api.JournalistRole ->
            "journalist"


parseEntryType : String -> Api.EntryType
parseEntryType s =
    case s of
        "substitute" ->
            Api.SubstituteEntry

        "non_active" ->
            Api.NonActiveEntry

        _ ->
            Api.ActiveEntry


parseRole : String -> Maybe Api.RosterRole
parseRole s =
    case s of
        "pretrial_attorney" ->
            Just Api.PretrialAttorneyRole

        "trial_attorney" ->
            Just Api.TrialAttorneyRole

        "witness" ->
            Just Api.WitnessRole

        "clerk" ->
            Just Api.ClerkRole

        "bailiff" ->
            Just Api.BailiffRole

        "artist" ->
            Just Api.ArtistRole

        "journalist" ->
            Just Api.JournalistRole

        _ ->
            Nothing


validateForm : FormData -> Result (List String) (List FormRow)
validateForm formData =
    let
        nonEmptyRows =
            List.filter (\r -> r.student /= "" || r.role /= "") formData.rows

        errors =
            nonEmptyRows
                |> List.indexedMap
                    (\i r ->
                        []
                            |> addErrorIf (r.student == "" && r.entryType /= "non_active")
                                ("Row " ++ String.fromInt (i + 1) ++ ": student is required.")
                            |> addErrorIf (r.entryType == "active" && r.role == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": role is required for active members.")
                            |> addErrorIf (r.role == "witness" && r.character == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": character is required for witnesses.")
                    )
                |> List.concat

        duplicateStudents =
            let
                studentIds =
                    List.filterMap
                        (\r ->
                            if r.student /= "" then
                                Just r.student

                            else
                                Nothing
                        )
                        nonEmptyRows

                hasDuplicates ids =
                    List.length ids /= List.length (unique ids)
            in
            if hasDuplicates studentIds then
                [ "Each student can only appear once per roster." ]

            else
                []
    in
    if List.isEmpty nonEmptyRows then
        Err [ "Add at least one roster entry." ]

    else if List.isEmpty errors && List.isEmpty duplicateStudents then
        Ok nonEmptyRows

    else
        Err (errors ++ duplicateStudents)


unique : List comparable -> List comparable
unique list =
    List.foldl
        (\item acc ->
            if List.member item acc then
                acc

            else
                acc ++ [ item ]
        )
        []
        list


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors


updateFormRows : (List FormRow -> List FormRow) -> FormState -> FormState
updateFormRows transform state =
    case state of
        FormEditing formData _ ->
            FormEditing { formData | rows = transform formData.rows } []

        _ ->
            state


updateRow : Int -> (FormRow -> FormRow) -> FormState -> FormState
updateRow idx transform state =
    updateFormRows
        (List.indexedMap
            (\i r ->
                if i == idx then
                    transform r

                else
                    r
            )
        )
        state


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


roleName : Maybe Api.RosterRole -> String
roleName maybeRole =
    case maybeRole of
        Nothing ->
            "—"

        Just Api.PretrialAttorneyRole ->
            "Pretrial Attorney"

        Just Api.TrialAttorneyRole ->
            "Trial Attorney"

        Just Api.WitnessRole ->
            "Witness"

        Just Api.ClerkRole ->
            "Clerk"

        Just Api.BailiffRole ->
            "Bailiff"

        Just Api.ArtistRole ->
            "Courtroom Artist"

        Just Api.JournalistRole ->
            "Courtroom Journalist"


entryTypeName : Api.EntryType -> String
entryTypeName et =
    case et of
        Api.ActiveEntry ->
            "Active"

        Api.SubstituteEntry ->
            "Substitute"

        Api.NonActiveEntry ->
            "Non-Active"


sideLabel : Api.RosterSide -> String
sideLabel side =
    case side of
        Api.Prosecution ->
            "Prosecution"

        Api.Defense ->
            "Defense"


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


roleOptionsForSide : Api.RosterSide -> List { value : String, label : String }
roleOptionsForSide side =
    let
        common =
            [ { value = "", label = "Select role..." }
            , { value = "pretrial_attorney", label = "Pretrial Attorney" }
            , { value = "trial_attorney", label = "Trial Attorney" }
            , { value = "witness", label = "Witness" }
            , { value = "artist", label = "Courtroom Artist" }
            , { value = "journalist", label = "Courtroom Journalist" }
            ]

        sideSpecific =
            case side of
                Api.Prosecution ->
                    [ { value = "clerk", label = "Clerk" } ]

                Api.Defense ->
                    [ { value = "bailiff", label = "Bailiff" } ]
    in
    common ++ sideSpecific



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
                        FormEditing fd _ ->
                            fd.roundId == round.id

                        FormSaving fd ->
                            fd.roundId == round.id

                        FormHidden ->
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
                    , UI.badge { label = sideLabel side, variant = sideVariant side }
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
        [ viewRosterEntries data entries side
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


viewRosterEntries : TeamData -> List Api.RosterEntry -> Api.RosterSide -> Html Msg
viewRosterEntries data entries side =
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
    in
    tr []
        [ td [] [ text (studentName data.students entry.student) ]
        , td [] [ text (roleName entry.role) ]
        , td [] [ text (characterName data.caseCharacters entry.character) ]
        , td []
            [ if List.isEmpty entryTasks then
                text ""

              else
                div [ Attr.class "flex flex-wrap gap-1" ]
                    (List.map viewTaskBadge entryTasks)
            ]
        ]


viewTaskBadge : Api.AttorneyTask -> Html Msg
viewTaskBadge task =
    span [ Attr.class "badge badge-ghost badge-sm" ]
        [ text (taskTypeName task.taskType) ]



-- FORM VIEW


viewRosterForm : TeamData -> Html Msg
viewRosterForm data =
    case data.form of
        FormEditing formData errors ->
            viewFormCard data formData errors False

        FormSaving formData ->
            viewFormCard data formData [] True

        FormHidden ->
            text ""


viewFormCard : TeamData -> FormData -> List String -> Bool -> Html Msg
viewFormCard data formData errors saving =
    let
        sideCharacters =
            data.caseCharacters
                |> List.filter (\c -> c.side == formData.side)

        assignedStudents =
            List.map .student formData.rows
                |> List.filter (\s -> s /= "")
    in
    div [ Attr.class "py-2" ]
        [ UI.errorList errors
        , table [ Attr.class "table table-sm w-full" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Student" ]
                    , th [] [ text "Type" ]
                    , th [] [ text "Role" ]
                    , th [] [ text "Character" ]
                    , th [] []
                    ]
                ]
            , tbody []
                (List.indexedMap
                    (viewFormRow data.students sideCharacters assignedStudents formData.side)
                    formData.rows
                )
            ]
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick AddRow
                , Attr.disabled saving
                ]
                [ text "+ Add Row" ]
            ]
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-primary btn-sm"
                , Events.onClick SaveDraft
                , Attr.disabled saving
                ]
                (if saving && not formData.submitting then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Saving..."
                    ]

                 else
                    [ text "Save Draft" ]
                )
            , button
                [ Attr.class "btn btn-success btn-sm"
                , Events.onClick SubmitRoster
                , Attr.disabled saving
                ]
                (if saving && formData.submitting then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Submitting..."
                    ]

                 else
                    [ text "Submit Roster" ]
                )
            , button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick CancelRosterForm
                , Attr.disabled saving
                ]
                [ text "Cancel" ]
            ]
        ]


viewFormRow : List Api.Student -> List Api.CaseCharacter -> List String -> Api.RosterSide -> Int -> FormRow -> Html Msg
viewFormRow students characters assignedStudents side idx row =
    let
        availableStudents =
            students
                |> List.filter
                    (\s ->
                        s.id == row.student || not (List.member s.id assignedStudents)
                    )
    in
    tr []
        [ td []
            [ select
                [ Attr.class "select select-sm select-bordered w-full"
                , Events.onInput (UpdateRowStudent idx)
                , Attr.value row.student
                ]
                ({ value = "", label = "Select student..." }
                    :: List.map (\s -> { value = s.id, label = s.name }) availableStudents
                    |> List.map (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.student) ] [ text o.label ])
                )
            ]
        , td []
            [ select
                [ Attr.class "select select-sm select-bordered"
                , Events.onInput (UpdateRowEntryType idx)
                , Attr.value row.entryType
                ]
                [ option [ Attr.value "active", Attr.selected (row.entryType == "active") ] [ text "Active" ]
                , option [ Attr.value "substitute", Attr.selected (row.entryType == "substitute") ] [ text "Substitute" ]
                , option [ Attr.value "non_active", Attr.selected (row.entryType == "non_active") ] [ text "Non-Active" ]
                ]
            ]
        , td []
            [ if row.entryType == "non_active" then
                text "—"

              else
                select
                    [ Attr.class "select select-sm select-bordered"
                    , Events.onInput (UpdateRowRole idx)
                    , Attr.value row.role
                    ]
                    (List.map
                        (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.role) ] [ text o.label ])
                        (roleOptionsForSide side)
                    )
            ]
        , td []
            [ if row.role == "witness" then
                select
                    [ Attr.class "select select-sm select-bordered"
                    , Events.onInput (UpdateRowCharacter idx)
                    , Attr.value row.character
                    ]
                    ({ value = "", label = "Select character..." }
                        :: List.map (\c -> { value = c.id, label = c.characterName }) characters
                        |> List.map (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.character) ] [ text o.label ])
                    )

              else
                text ""
            ]
        , td []
            [ button
                [ Attr.class "btn btn-ghost btn-sm btn-square text-error"
                , Events.onClick (RemoveRow idx)
                ]
                [ text "×" ]
            ]
        ]
