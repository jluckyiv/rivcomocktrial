module Pages.Admin.Teams exposing (Model, Msg, page)

import Api exposing (School, Team, Tournament)
import Auth
import Effect exposing (Effect)
import Error exposing (Error(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import Team
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


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { teams = Loading
      , tournaments = []
      , schools = []
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      , filterTournament = ""
      }
    , Effect.batch
        [ Effect.sendCmd (Api.listTeams user.token GotTeams)
        , Effect.sendCmd (Api.listTournaments user.token GotTournaments)
        , Effect.sendCmd (Api.listSchools user.token GotSchools)
        ]
    )



-- UPDATE


type Msg
    = GotTeams (Result Http.Error (Api.ListResponse Team))
    | GotTournaments (Result Http.Error (Api.ListResponse Tournament))
    | GotSchools (Result Http.Error (Api.ListResponse School))
    | FilterTournamentChanged String
    | ShowCreateForm
    | EditTeam Team
    | CancelForm
    | FormTournamentChanged String
    | FormSchoolChanged String
    | FormTeamNumberChanged String
    | FormNameChanged String
    | SaveTeam
    | GotSaveResponse (Result Http.Error Team)
    | DeleteTeam String
    | GotDeleteResponse String (Result Http.Error ())
    | BulkTextChanged String
    | BulkImport
    | GotBulkResponse (Result Http.Error Team)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotTeams (Ok response) ->
            ( { model | teams = Succeeded response.items }, Effect.none )

        GotTeams (Err _) ->
            ( { model | teams = Failed "Failed to load teams." }, Effect.none )

        GotTournaments (Ok response) ->
            ( { model | tournaments = response.items }, Effect.none )

        GotTournaments (Err _) ->
            ( model, Effect.none )

        GotSchools (Ok response) ->
            ( { model | schools = response.items }, Effect.none )

        GotSchools (Err _) ->
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
              }
            , Effect.none
            )

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
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

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
                                cmd =
                                    case context of
                                        Editing id ->
                                            Api.updateTeam user.token id data GotSaveResponse

                                        Creating ->
                                            Api.createTeam user.token data GotSaveResponse
                            in
                            ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok team) ->
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

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData [ "Failed to save team." ] }, Effect.none )

                _ ->
                    ( model, Effect.none )

        DeleteTeam id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteTeam user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | teams = RemoteData.map (List.filter (\t -> t.id /= id)) model.teams
                , deleting = Nothing
              }
            , Effect.none
            )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing }, Effect.none )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        BulkImport ->
            handleBulkImport user model

        GotBulkResponse (Ok team) ->
            ( { model
                | teams = RemoteData.map (\list -> list ++ [ team ]) model.teams
                , bulk = BulkIdle
              }
            , Effect.none
            )

        GotBulkResponse (Err _) ->
            case model.bulk of
                BulkSaving val ->
                    ( { model | bulk = BulkFailed val "Failed to create some teams." }, Effect.none )

                _ ->
                    ( { model | bulk = BulkFailed "" "Failed to create some teams." }, Effect.none )



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
            List.map (\(Error msg) -> msg)

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


handleBulkImport : Auth.User -> Model -> ( Model, Effect Msg )
handleBulkImport user model =
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
                        Effect.sendCmd
                            (Api.createTeam user.token
                                { tournament = model.filterTournament
                                , school = data.school
                                , teamNumber = data.teamNumber
                                , name = data.name
                                }
                                GotBulkResponse
                            )
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
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Teams"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Teams" ] ]
            , div [ Attr.class "level-right" ]
                [ div [ Attr.class "field has-addons" ]
                    [ div [ Attr.class "control" ]
                        [ div [ Attr.class "select" ]
                            [ select [ Events.onInput FilterTournamentChanged ]
                                (option [ Attr.value "" ] [ text "All Tournaments" ]
                                    :: List.map
                                        (\t ->
                                            option [ Attr.value t.id, Attr.selected (model.filterTournament == t.id) ]
                                                [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                        )
                                        model.tournaments
                                )
                            ]
                        ]
                    , div [ Attr.class "control" ]
                        [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                            [ text "New Team" ]
                        ]
                    ]
                ]
            ]
        , viewForm model.form model.tournaments model.schools
        , viewBulkInput model.bulk model.filterTournament
        , viewTeams model.teams model.tournaments model.schools model.deleting model.filterTournament
        ]
    }


viewTeams : RemoteData (List Team) -> List Tournament -> List School -> Maybe String -> String -> Html Msg
viewTeams teams tournaments schools deleting filterTournament =
    case teams of
        NotAsked ->
            text ""

        Loading ->
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

        Failed err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Succeeded list ->
            viewTable list tournaments schools deleting filterTournament


viewForm : FormState -> List Tournament -> List School -> Html Msg
viewForm state tournaments schools =
    case state of
        FormHidden ->
            text ""

        FormOpen context formData errors ->
            viewFormBox context formData errors False tournaments schools

        FormSaving context formData ->
            viewFormBox context formData [] True tournaments schools


viewFormBox : FormContext -> TeamForm -> List String -> Bool -> List Tournament -> List School -> Html Msg
viewFormBox context formData errors saving tournaments schools =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit Team"

                    Creating ->
                        "New Team"
                )
            ]
        , viewErrors errors
        , Html.form [ Events.onSubmit SaveTeam ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Tournament" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormTournamentChanged ]
                                    (option [ Attr.value "" ] [ text "Select tournament..." ]
                                        :: List.map
                                            (\t ->
                                                option [ Attr.value t.id, Attr.selected (formData.tournament == t.id) ]
                                                    [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                            )
                                            tournaments
                                    )
                                ]
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "School" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormSchoolChanged ]
                                    (option [ Attr.value "" ] [ text "Select school..." ]
                                        :: List.map
                                            (\s ->
                                                option [ Attr.value s.id, Attr.selected (formData.school == s.id) ]
                                                    [ text s.name ]
                                            )
                                            schools
                                    )
                                ]
                            ]
                        ]
                    ]
                ]
            , div [ Attr.class "columns" ]
                [ div [ Attr.class "column is-3" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Team Number" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.type_ "number"
                                , Attr.value formData.teamNumber
                                , Events.onInput FormTeamNumberChanged
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Team Name/Label" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value formData.name
                                , Events.onInput FormNameChanged
                                ]
                                []
                            ]
                        ]
                    ]
                ]
            , div [ Attr.class "field is-grouped" ]
                [ div [ Attr.class "control" ]
                    [ button
                        [ Attr.class
                            (if saving then
                                "button is-primary is-loading"

                             else
                                "button is-primary"
                            )
                        , Attr.type_ "submit"
                        ]
                        [ text "Save" ]
                    ]
                , div [ Attr.class "control" ]
                    [ button [ Attr.class "button", Attr.type_ "button", Events.onClick CancelForm ]
                        [ text "Cancel" ]
                    ]
                ]
            ]
        ]


viewBulkInput : BulkState -> String -> Html Msg
viewBulkInput state filterTournament =
    let
        ( bulkText, bulkError, saving ) =
            case state of
                BulkIdle ->
                    ( "", Nothing, False )

                BulkEditing val ->
                    ( val, Nothing, False )

                BulkSaving val ->
                    ( val, Nothing, True )

                BulkFailed val err ->
                    ( val, Just err, False )
    in
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ] [ text "Bulk Import" ]
        , p [ Attr.class "help mb-3" ]
            [ text "One team per line. Format: "
            , code [] [ text "{number} {name}, {school_name}" ]
            , br [] []
            , text "Teams are added to the selected tournament filter."
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ textarea
                    [ Attr.class "textarea"
                    , Attr.rows 6
                    , Attr.placeholder "101 Lions A, Lincoln High\n102 Lions B, Lincoln High\n201 Eagles, Kennedy Middle"
                    , Attr.value bulkText
                    , Events.onInput BulkTextChanged
                    ]
                    []
                ]
            ]
        , case bulkError of
            Just err ->
                div [ Attr.class "notification is-danger is-light" ] [ text err ]

            Nothing ->
                text ""
        , div [ Attr.class "field" ]
            [ button
                [ Attr.class
                    (if saving then
                        "button is-info is-loading"

                     else
                        "button is-info"
                    )
                , Events.onClick BulkImport
                , Attr.disabled (String.trim bulkText == "" || filterTournament == "")
                ]
                [ text "Import" ]
            ]
        ]


viewTable : List Team -> List Tournament -> List School -> Maybe String -> String -> Html Msg
viewTable teams tournaments schools deleting filterTournament =
    let
        filtered =
            if filterTournament == "" then
                teams

            else
                List.filter (\t -> t.tournament == filterTournament) teams

        findName items id =
            List.filter (\item -> item.id == id) items
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault id
    in
    if List.isEmpty filtered then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No teams yet." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "#" ]
                    , th [] [ text "Name" ]
                    , th [] [ text "School" ]
                    , th [] [ text "Tournament" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody []
                (List.map
                    (\t ->
                        viewRow deleting
                            (findName (List.map (\s -> { id = s.id, name = s.name }) schools))
                            (findName (List.map (\tn -> { id = tn.id, name = tn.name }) tournaments))
                            t
                    )
                    filtered
                )
            ]


viewRow : Maybe String -> (String -> String) -> (String -> String) -> Team -> Html Msg
viewRow deleting schoolName tournamentName t =
    tr []
        [ td [] [ text (String.fromInt t.teamNumber) ]
        , td [] [ text t.name ]
        , td [] [ text (schoolName t.school) ]
        , td [] [ text (tournamentName t.tournament) ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditTeam t) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if deleting == Just t.id then
                            "button is-danger is-outlined is-loading"

                         else
                            "button is-danger is-outlined"
                        )
                    , Events.onClick (DeleteTeam t.id)
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]


viewErrors : List String -> Html msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "notification is-danger is-light" ]
            [ ul [] (List.map (\e -> li [] [ text e ]) errors) ]
