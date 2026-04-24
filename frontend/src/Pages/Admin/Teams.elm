module Pages.Admin.Teams exposing (Model, Msg, page)

import Api exposing (School, Team, Tournament)
import Auth
import Effect exposing (Effect)
import Error exposing (Error(..))
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
import Team
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



-- TYPES


type FormContext
    = Creating
    | Editing String


type alias TeamForm =
    { tournament : String
    , school : String
    , teamNumber : String
    , name : String
    }


type FormState
    = FormHidden
    | FormOpen FormContext TeamForm (List String)
    | FormSaving FormContext TeamForm


type BulkState
    = BulkIdle
    | BulkEditing String
    | BulkSaving String
    | BulkFailed String String



-- MODEL


type alias Model =
    { teams : RemoteData (List Team)
    , tournaments : List Tournament
    , schools : List School
    , form : FormState
    , bulk : BulkState
    , deleting : Maybe String
    , filterTournament : String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { teams = Loading
      , tournaments = []
      , schools = []
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      , filterTournament = ""
      }
    , Effect.batch
        [ Pb.adminList { collection = "teams", tag = "teams", filter = "", sort = "" }
        , Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
        , Pb.adminList { collection = "schools", tag = "schools", filter = "", sort = "" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterTournamentChanged String
    | ShowCreateForm
    | ShowBulkImport
    | EditTeam Team
    | CancelForm
    | CancelBulk
    | FormTournamentChanged String
    | FormSchoolChanged String
    | FormTeamNumberChanged String
    | FormNameChanged String
    | SaveTeam
    | DeleteTeam String
    | BulkTextChanged String
    | BulkImport


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "teams" ->
                    case Pb.decodeList Api.teamDecoder value of
                        Ok items ->
                            ( { model | teams = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | teams = Failed "Failed to load teams." }, Effect.none )

                Just "tournaments" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok items ->
                            ( { model | tournaments = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "schools" ->
                    case Pb.decodeList Api.schoolDecoder value of
                        Ok items ->
                            ( { model | schools = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-team" ->
                    case Pb.decodeRecord Api.teamDecoder value of
                        Ok team ->
                            let
                                updateTeams context teams =
                                    case context of
                                        Editing _ ->
                                            List.map
                                                (\t ->
                                                    if t.id == team.id then
                                                        team

                                                    else
                                                        t
                                                )
                                                teams

                                        Creating ->
                                            teams ++ [ team ]
                            in
                            case model.form of
                                FormSaving context _ ->
                                    ( { model
                                        | teams = RemoteData.map (updateTeams context) model.teams
                                        , form = FormHidden
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save team." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-team" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | teams = RemoteData.map (List.filter (\t -> t.id /= id)) model.teams
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                Just "bulk-team" ->
                    case Pb.decodeRecord Api.teamDecoder value of
                        Ok team ->
                            ( { model
                                | teams = RemoteData.map (\list -> list ++ [ team ]) model.teams
                                , bulk = BulkIdle
                              }
                            , Effect.none
                            )

                        Err _ ->
                            case model.bulk of
                                BulkSaving val ->
                                    ( { model | bulk = BulkFailed val "Failed to create some teams." }, Effect.none )

                                _ ->
                                    ( { model | bulk = BulkFailed "" "Failed to create some teams." }, Effect.none )

                _ ->
                    ( model, Effect.none )

        FilterTournamentChanged val ->
            ( { model | filterTournament = val }, Effect.none )

        ShowCreateForm ->
            ( { model
                | form =
                    FormOpen Creating
                        { tournament = model.filterTournament
                        , school = ""
                        , teamNumber = ""
                        , name = ""
                        }
                        []
                , bulk = BulkIdle
              }
            , Effect.none
            )

        ShowBulkImport ->
            ( { model | bulk = BulkEditing "", form = FormHidden }, Effect.none )

        EditTeam t ->
            ( { model
                | form =
                    FormOpen (Editing t.id)
                        { tournament = t.tournament
                        , school = t.school
                        , teamNumber = String.fromInt t.teamNumber
                        , name = t.name
                        }
                        []
                , bulk = BulkIdle
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        CancelBulk ->
            ( { model | bulk = BulkIdle }, Effect.none )

        FormTournamentChanged val ->
            ( { model | form = updateFormField (\f -> { f | tournament = val }) model.form }, Effect.none )

        FormSchoolChanged val ->
            ( { model | form = updateFormField (\f -> { f | school = val }) model.form }, Effect.none )

        FormTeamNumberChanged val ->
            ( { model | form = updateFormField (\f -> { f | teamNumber = val }) model.form }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        SaveTeam ->
            case model.form of
                FormOpen context formData _ ->
                    case validateForm formData of
                        Err errors ->
                            ( { model | form = FormOpen context formData errors }, Effect.none )

                        Ok data ->
                            let
                                effect =
                                    case context of
                                        Editing id ->
                                            Pb.adminUpdate
                                                { collection = "teams"
                                                , id = id
                                                , tag = "save-team"
                                                , body = Api.encodeTeam data
                                                }

                                        Creating ->
                                            Pb.adminCreate
                                                { collection = "teams"
                                                , tag = "save-team"
                                                , body = Api.encodeTeam data
                                                }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteTeam id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "teams", id = id, tag = "delete-team" }
            )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        BulkImport ->
            handleBulkImport model



-- HELPERS


updateFormField : (TeamForm -> TeamForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData _ ->
            FormOpen context (transform formData) []

        _ ->
            state


type alias ValidatedTeam =
    { tournament : String
    , school : String
    , teamNumber : Int
    , name : String
    }


validateForm : TeamForm -> Result (List String) ValidatedTeam
validateForm formData =
    let
        toStrings =
            List.map (\(Error msg_) -> msg_)

        tournamentValidation =
            if String.trim formData.tournament == "" then
                Err [ "Tournament is required." ]

            else
                Ok ()

        schoolValidation =
            if String.trim formData.school == "" then
                Err [ "School is required." ]

            else
                Ok ()

        teamNumberValidation =
            case String.toInt (String.trim formData.teamNumber) of
                Nothing ->
                    Err [ "Team number must be a valid integer." ]

                Just n ->
                    Team.numberFromInt n |> Result.mapError toStrings

        nameValidation =
            Team.nameFromString formData.name |> Result.mapError toStrings

        collectErrors results =
            List.concatMap
                (\r ->
                    case r of
                        Err errs ->
                            errs

                        Ok _ ->
                            []
                )
                results

        allErrors =
            collectErrors
                [ tournamentValidation
                , schoolValidation
                , teamNumberValidation |> Result.map (\_ -> ())
                , nameValidation |> Result.map (\_ -> ())
                ]
    in
    if List.isEmpty allErrors then
        Ok
            { tournament = String.trim formData.tournament
            , school = String.trim formData.school
            , teamNumber = String.toInt (String.trim formData.teamNumber) |> Maybe.withDefault 0
            , name = String.trim formData.name
            }

    else
        Err allErrors


handleBulkImport : Model -> ( Model, Effect Msg )
handleBulkImport model =
    if model.filterTournament == "" then
        ( { model | bulk = BulkFailed (bulkTextFromState model.bulk) "Select a tournament first." }, Effect.none )

    else
        let
            bulkText =
                bulkTextFromState model.bulk

            lines =
                String.lines bulkText
                    |> List.map String.trim
                    |> List.filter (\l -> l /= "")

            parsed =
                List.filterMap (parseBulkLine model.schools) lines

            errors =
                List.length lines - List.length parsed
        in
        if List.isEmpty parsed then
            ( { model | bulk = BulkFailed bulkText "No valid lines found. Format: 101 Team Name, School Name" }, Effect.none )

        else if errors > 0 then
            ( { model | bulk = BulkFailed bulkText (String.fromInt errors ++ " line(s) could not be parsed. Check school names match exactly.") }, Effect.none )

        else
            ( { model | bulk = BulkSaving bulkText }
            , Effect.batch
                (List.map
                    (\data ->
                        Pb.adminCreate
                            { collection = "teams"
                            , tag = "bulk-team"
                            , body =
                                Api.encodeTeam
                                    { tournament = model.filterTournament
                                    , school = data.school
                                    , teamNumber = data.teamNumber
                                    , name = data.name
                                    }
                            }
                    )
                    parsed
                )
            )


bulkTextFromState : BulkState -> String
bulkTextFromState state =
    case state of
        BulkEditing val ->
            val

        BulkFailed val _ ->
            val

        _ ->
            ""



-- BULK PARSING


parseBulkLine : List School -> String -> Maybe { teamNumber : Int, name : String, school : String }
parseBulkLine schools line =
    -- Format: {number} {name}, {school_name}
    case String.split "," line |> List.map String.trim of
        [ numAndName, schoolName ] ->
            let
                schoolId =
                    schools
                        |> List.filter (\s -> String.toLower s.name == String.toLower schoolName)
                        |> List.head
                        |> Maybe.map .id
                        |> Maybe.withDefault ""

                parts =
                    String.words numAndName
            in
            case parts of
                numStr :: nameParts ->
                    case String.toInt numStr of
                        Just num ->
                            if schoolId /= "" then
                                Just
                                    { teamNumber = num
                                    , name = String.join " " nameParts
                                    , school = schoolId
                                    }

                            else
                                Nothing

                        Nothing ->
                            Nothing

                _ ->
                    Nothing

        _ ->
            Nothing



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Teams"
    , body =
        [ UI.titleBar
            { title = "Teams"
            , actions =
                [ { label = "New Team", msg = ShowCreateForm }
                , { label = "Bulk Import", msg = ShowBulkImport }
                ]
            }
        , UI.filterSelect
            { label = "Tournament:"
            , value = model.filterTournament
            , onInput = FilterTournamentChanged
            , options =
                { value = "", label = "All Tournaments" }
                    :: List.map (\t -> { value = t.id, label = t.name ++ " (" ++ String.fromInt t.year ++ ")" }) model.tournaments
            }
        , viewForm model.form model.tournaments model.schools
        , viewBulkInput model.bulk model.filterTournament
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.teams of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded teams ->
            let
                filtered =
                    if model.filterTournament == "" then
                        teams

                    else
                        List.filter (\t -> t.tournament == model.filterTournament) teams

                findName items id =
                    List.filter (\item -> item.id == id) items
                        |> List.head
                        |> Maybe.map .name
                        |> Maybe.withDefault id

                schoolName =
                    findName (List.map (\s -> { id = s.id, name = s.name }) model.schools)

                tournamentName =
                    findName (List.map (\t -> { id = t.id, name = t.name }) model.tournaments)
            in
            if List.isEmpty filtered then
                UI.emptyState "No teams yet."

            else
                UI.dataTable
                    { columns = [ "#", "Name", "School", "Tournament", "Actions" ]
                    , rows = filtered
                    , rowView = viewRow model.deleting schoolName tournamentName
                    }


viewForm : FormState -> List Tournament -> List School -> Html Msg
viewForm state tournaments schools =
    case state of
        FormHidden ->
            UI.empty

        FormOpen context formData errors ->
            viewFormCard context formData errors False tournaments schools

        FormSaving context formData ->
            viewFormCard context formData [] True tournaments schools


viewFormCard : FormContext -> TeamForm -> List String -> Bool -> List Tournament -> List School -> Html Msg
viewFormCard context formData errors saving tournaments schools =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Team"

                    Editing _ ->
                        "Edit Team"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveTeam ]
                [ UI.formColumns
                    [ UI.selectField
                        { label = "Tournament"
                        , value = formData.tournament
                        , onInput = FormTournamentChanged
                        , options =
                            { value = "", label = "Select tournament..." }
                                :: List.map (\t -> { value = t.id, label = t.name ++ " (" ++ String.fromInt t.year ++ ")" }) tournaments
                        }
                    , UI.selectField
                        { label = "School"
                        , value = formData.school
                        , onInput = FormSchoolChanged
                        , options =
                            { value = "", label = "Select school..." }
                                :: List.map (\s -> { value = s.id, label = s.name }) schools
                        }
                    ]
                , UI.formColumns
                    [ UI.numberField
                        { label = "Team Number"
                        , value = formData.teamNumber
                        , onInput = FormTeamNumberChanged
                        , required = False
                        }
                    , UI.textField
                        { label = "Team Name/Label"
                        , value = formData.name
                        , onInput = FormNameChanged
                        , required = False
                        }
                    ]
                , div [ Attr.class "flex gap-2 mt-4" ]
                    [ UI.primaryButton { label = "Save", loading = saving }
                    , UI.cancelButton CancelForm
                    ]
                ]
            ]
        ]


viewBulkInput : BulkState -> String -> Html Msg
viewBulkInput state filterTournament =
    case state of
        BulkIdle ->
            UI.empty

        _ ->
            let
                ( bulkText, bulkError, saving ) =
                    case state of
                        BulkEditing val ->
                            ( val, Nothing, False )

                        BulkSaving val ->
                            ( val, Nothing, True )

                        BulkFailed val err ->
                            ( val, Just err, False )

                        BulkIdle ->
                            ( "", Nothing, False )
            in
            UI.card
                [ UI.cardBody
                    [ UI.cardTitle "Bulk Import"
                    , p [ Attr.class "text-sm text-base-content/70 mb-3" ]
                        [ text "One team per line. Format: "
                        , code [] [ text "{number} {name}, {school_name}" ]
                        , br [] []
                        , text "Teams are added to the selected tournament filter."
                        ]
                    , UI.textareaField
                        { label = ""
                        , value = bulkText
                        , onInput = BulkTextChanged
                        , rows = 6
                        , placeholder = "101 Lions A, Lincoln High\n102 Lions B, Lincoln High\n201 Eagles, Kennedy Middle"
                        }
                    , case bulkError of
                        Just err ->
                            div [ Attr.class "mt-2" ] [ UI.error err ]

                        Nothing ->
                            UI.empty
                    , div [ Attr.class "flex gap-2 mt-4" ]
                        [ button
                            [ Attr.class "btn btn-info"
                            , Events.onClick BulkImport
                            , Attr.disabled (saving || String.trim bulkText == "" || filterTournament == "")
                            ]
                            (if saving then
                                [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                                , text "Importing..."
                                ]

                             else
                                [ text "Import" ]
                            )
                        , UI.cancelButton CancelBulk
                        ]
                    ]
                ]


viewRow : Maybe String -> (String -> String) -> (String -> String) -> Team -> Html Msg
viewRow deleting schoolName tournamentName t =
    tr []
        [ td [] [ text (String.fromInt t.teamNumber) ]
        , td [] [ text t.name ]
        , td [] [ text (schoolName t.school) ]
        , td [] [ text (tournamentName t.tournament) ]
        , td []
            [ div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-outline btn-info"
                    , Events.onClick (EditTeam t)
                    ]
                    [ text "Edit" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-error"
                    , Events.onClick (DeleteTeam t.id)
                    , Attr.disabled (deleting == Just t.id)
                    ]
                    (if deleting == Just t.id then
                        [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                     else
                        [ text "Delete" ]
                    )
                ]
            ]
        ]
