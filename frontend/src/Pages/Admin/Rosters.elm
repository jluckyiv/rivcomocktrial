module Pages.Admin.Rosters exposing (Model, Msg, page)

import Api exposing (CaseCharacter, RosterEntry, RosterSubmission, Round, Student, Team, Tournament)
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode
import Layouts
import Page exposing (Page)
import Pb
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import UI
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init user
        , update = update user
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


type FormState
    = FormHidden
    | FormEditing FormData (List String)
    | FormSaving FormData


type alias FormData =
    { teamId : String
    , roundId : String
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
    , form : FormState
    , savesPending : Int
    , deletesPending : Int
    }


emptyRow : FormRow
emptyRow =
    { id = Nothing
    , student = ""
    , entryType = "active"
    , role = ""
    , character = ""
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
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
      , form = FormHidden
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


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
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
                , form = FormHidden
              }
            , Effect.none
            )

        CloseCell ->
            ( { model | selectedCell = Nothing, form = FormHidden }, Effect.none )

        EditRoster ->
            case model.selectedCell of
                Just cell ->
                    let
                        existingEntries =
                            entriesForCell cell.teamId cell.roundId cell.side model.entries

                        rows =
                            if List.isEmpty existingEntries then
                                [ emptyRow ]

                            else
                                List.map entryToFormRow existingEntries
                    in
                    ( { model
                        | form =
                            FormEditing
                                { teamId = cell.teamId
                                , roundId = cell.roundId
                                , side = cell.side
                                , rows = rows
                                , submitting = False
                                }
                                []
                      }
                    , Effect.none
                    )

                Nothing ->
                    ( model, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        AddRow ->
            ( { model | form = updateFormRows (\rows -> rows ++ [ emptyRow ]) model.form }
            , Effect.none
            )

        RemoveRow idx ->
            ( { model
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
                        model.form
              }
            , Effect.none
            )

        UpdateRowStudent idx val ->
            ( { model | form = updateRow idx (\r -> { r | student = val }) model.form }, Effect.none )

        UpdateRowEntryType idx val ->
            ( { model | form = updateRow idx (\r -> { r | entryType = val, role = "", character = "" }) model.form }, Effect.none )

        UpdateRowRole idx val ->
            let
                clearCharacter r =
                    if val /= "witness" then
                        { r | role = val, character = "" }

                    else
                        { r | role = val }
            in
            ( { model | form = updateRow idx clearCharacter model.form }, Effect.none )

        UpdateRowCharacter idx val ->
            ( { model | form = updateRow idx (\r -> { r | character = val }) model.form }, Effect.none )

        SaveDraft ->
            handleSave False model

        SubmitRoster ->
            handleSave True model


handleSave : Bool -> Model -> ( Model, Effect Msg )
handleSave submitting model =
    case model.form of
        FormEditing formData _ ->
            case validateForm formData of
                Err errors ->
                    ( { model | form = FormEditing formData errors }, Effect.none )

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

                        savingFormData =
                            { formData | submitting = submitting }
                    in
                    ( { model
                        | form = FormSaving savingFormData
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
        ( { model | form = FormHidden, savesPending = 0, deletesPending = 0 }, Effect.none )

    else
        ( model, Effect.none )


handleSaveError : String -> Model -> ( Model, Effect Msg )
handleSaveError err model =
    case model.form of
        FormSaving formData ->
            ( { model
                | form = FormEditing formData [ err ]
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


entryToFormRow : RosterEntry -> FormRow
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


sideLabel : Api.RosterSide -> String
sideLabel side =
    case side of
        Api.Prosecution ->
            "Prosecution"

        Api.Defense ->
            "Defense"


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
    div [ Attr.class "flex gap-4 mb-4" ]
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
    div [ Attr.class "overflow-x-auto" ]
        [ table [ Attr.class "table table-sm table-zebra w-full" ]
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
        ]


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
    td
        [ Attr.class "text-center cursor-pointer hover:bg-base-300"
        , Attr.classList [ ( "bg-base-300 ring-2 ring-primary", isSelected ) ]
        , Events.onClick (SelectCell teamId roundId side)
        ]
        [ statusBadge maybeSub ]


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

                maybeSub =
                    submissionForCell cell.teamId cell.roundId cell.side model.submissions
            in
            UI.card
                [ UI.cardBody
                    [ div [ Attr.class "flex items-center justify-between" ]
                        [ UI.cardTitle
                            (cellTeamName
                                ++ " — "
                                ++ cellRoundNumber
                                ++ " — "
                                ++ sideLabel cell.side
                            )
                        , button
                            [ Attr.class "btn btn-ghost btn-sm btn-square"
                            , Events.onClick CloseCell
                            ]
                            [ text "×" ]
                        ]
                    , case model.form of
                        FormHidden ->
                            viewCellReadOnly cellEntries maybeSub model

                        FormEditing _ _ ->
                            viewFormCard model

                        FormSaving _ ->
                            viewFormCard model
                    ]
                ]


viewCellReadOnly : List RosterEntry -> Maybe RosterSubmission -> Model -> Html Msg
viewCellReadOnly entries maybeSub model =
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
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-primary btn-sm"
                , Events.onClick EditRoster
                ]
                [ text "Edit Roster" ]
            ]
        ]


viewReadOnlyRow : Model -> RosterEntry -> Html Msg
viewReadOnlyRow model entry =
    tr []
        [ td [] [ text (studentName (Maybe.withDefault "" entry.student) model.students) ]
        , td [] [ text (roleName entry.role) ]
        , td [] [ text (characterNameById (Maybe.withDefault "" entry.character) model.caseCharacters) ]
        ]


viewFormCard : Model -> Html Msg
viewFormCard model =
    case model.form of
        FormEditing formData errors ->
            viewFormContent model formData errors False

        FormSaving formData ->
            viewFormContent model formData [] True

        FormHidden ->
            text ""


viewFormContent : Model -> FormData -> List String -> Bool -> Html Msg
viewFormContent model formData errors saving =
    let
        sideCharacters =
            model.caseCharacters
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
                    (viewFormRow model.students sideCharacters assignedStudents formData.side)
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
                , Events.onClick CancelForm
                , Attr.disabled saving
                ]
                [ text "Cancel" ]
            ]
        ]


viewFormRow : List Student -> List CaseCharacter -> List String -> Api.RosterSide -> Int -> FormRow -> Html Msg
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
