module Pages.Admin.Teams exposing (Model, Msg, page)

import Api exposing (School, Team, Tournament)
import Auth
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Shared
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


type alias Model =
    { teams : List Team
    , tournaments : List Tournament
    , schools : List School
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formTournament : String
    , formSchool : String
    , formTeamNumber : String
    , formName : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    , filterTournament : String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { teams = []
      , tournaments = []
      , schools = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formTournament = ""
      , formSchool = ""
      , formTeamNumber = ""
      , formName = ""
      , formSaving = False
      , editingId = Nothing
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


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotTeams (Ok response) ->
            ( { model | teams = response.items, loading = False }, Effect.none )

        GotTeams (Err _) ->
            ( { model | loading = False, error = Just "Failed to load teams." }, Effect.none )

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
                | showForm = True
                , editingId = Nothing
                , formTournament = model.filterTournament
                , formSchool = ""
                , formTeamNumber = ""
                , formName = ""
              }
            , Effect.none
            )

        EditTeam t ->
            ( { model
                | showForm = True
                , editingId = Just t.id
                , formTournament = t.tournament
                , formSchool = t.school
                , formTeamNumber = String.fromInt t.teamNumber
                , formName = t.name
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }, Effect.none )

        FormTournamentChanged val ->
            ( { model | formTournament = val }, Effect.none )

        FormSchoolChanged val ->
            ( { model | formSchool = val }, Effect.none )

        FormTeamNumberChanged val ->
            ( { model | formTeamNumber = val }, Effect.none )

        FormNameChanged val ->
            ( { model | formName = val }, Effect.none )

        SaveTeam ->
            let
                data =
                    { tournament = model.formTournament
                    , school = model.formSchool
                    , teamNumber = String.toInt model.formTeamNumber |> Maybe.withDefault 0
                    , name = model.formName
                    }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateTeam user.token id data GotSaveResponse

                        Nothing ->
                            Api.createTeam user.token data GotSaveResponse
            in
            ( { model | formSaving = True }, Effect.sendCmd cmd )

        GotSaveResponse (Ok team) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\t ->
                                    if t.id == team.id then
                                        team

                                    else
                                        t
                                )
                                model.teams

                        Nothing ->
                            model.teams ++ [ team ]
            in
            ( { model | teams = updatedList, showForm = False, editingId = Nothing, formSaving = False }, Effect.none )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save team." }, Effect.none )

        DeleteTeam id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteTeam user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model | teams = List.filter (\t -> t.id /= id) model.teams, deleting = Nothing }, Effect.none )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete team." }, Effect.none )



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
        , viewError model.error
        , if model.showForm then
            viewForm model

          else
            text ""
        , if model.loading then
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

          else
            viewTable model
        ]
    }


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Just err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Nothing ->
            text ""


viewForm : Model -> Html Msg
viewForm model =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case model.editingId of
                    Just _ ->
                        "Edit Team"

                    Nothing ->
                        "New Team"
                )
            ]
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
                                                option [ Attr.value t.id, Attr.selected (model.formTournament == t.id) ]
                                                    [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                            )
                                            model.tournaments
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
                                                option [ Attr.value s.id, Attr.selected (model.formSchool == s.id) ]
                                                    [ text s.name ]
                                            )
                                            model.schools
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
                                , Attr.value model.formTeamNumber
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
                                , Attr.value model.formName
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
                            (if model.formSaving then
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


viewTable : Model -> Html Msg
viewTable model =
    let
        filtered =
            if model.filterTournament == "" then
                model.teams

            else
                List.filter (\t -> t.tournament == model.filterTournament) model.teams

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
                        tr []
                            [ td [] [ text (String.fromInt t.teamNumber) ]
                            , td [] [ text t.name ]
                            , td [] [ text (findName (List.map (\s -> { id = s.id, name = s.name }) model.schools) t.school) ]
                            , td [] [ text (findName (List.map (\tn -> { id = tn.id, name = tn.name }) model.tournaments) t.tournament) ]
                            , td []
                                [ div [ Attr.class "buttons are-small" ]
                                    [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditTeam t) ]
                                        [ text "Edit" ]
                                    , button
                                        [ Attr.class
                                            (if model.deleting == Just t.id then
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
                    )
                    filtered
                )
            ]
