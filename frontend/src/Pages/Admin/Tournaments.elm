module Pages.Admin.Tournaments exposing (Model, Msg, page)

import Api exposing (Tournament)
import Auth
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
        { init = init user
        , update = update user
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (\_ -> Layouts.Admin {})



-- MODEL


type alias Model =
    { tournaments : List Tournament
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formName : String
    , formYear : String
    , formPrelimRounds : String
    , formElimRounds : String
    , formStatus : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { tournaments = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formName = ""
      , formYear = ""
      , formPrelimRounds = "4"
      , formElimRounds = "3"
      , formStatus = "draft"
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      }
    , Effect.sendCmd (Api.listTournaments user.token GotTournaments)
    )



-- UPDATE


type Msg
    = GotTournaments (Result Http.Error (Api.ListResponse Tournament))
    | ShowCreateForm
    | EditTournament Tournament
    | CancelForm
    | FormNameChanged String
    | FormYearChanged String
    | FormPrelimRoundsChanged String
    | FormElimRoundsChanged String
    | FormStatusChanged String
    | SaveTournament
    | GotSaveResponse (Result Http.Error Tournament)
    | DeleteTournament String
    | GotDeleteResponse String (Result Http.Error ())


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotTournaments (Ok response) ->
            ( { model | tournaments = response.items, loading = False }
            , Effect.none
            )

        GotTournaments (Err _) ->
            ( { model | loading = False, error = Just "Failed to load tournaments." }
            , Effect.none
            )

        ShowCreateForm ->
            ( { model
                | showForm = True
                , editingId = Nothing
                , formName = ""
                , formYear = ""
                , formPrelimRounds = "4"
                , formElimRounds = "3"
                , formStatus = "draft"
              }
            , Effect.none
            )

        EditTournament t ->
            ( { model
                | showForm = True
                , editingId = Just t.id
                , formName = t.name
                , formYear = String.fromInt t.year
                , formPrelimRounds = String.fromInt t.numPreliminaryRounds
                , formElimRounds = String.fromInt t.numEliminationRounds
                , formStatus = t.status
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }
            , Effect.none
            )

        FormNameChanged val ->
            ( { model | formName = val }, Effect.none )

        FormYearChanged val ->
            ( { model | formYear = val }, Effect.none )

        FormPrelimRoundsChanged val ->
            ( { model | formPrelimRounds = val }, Effect.none )

        FormElimRoundsChanged val ->
            ( { model | formElimRounds = val }, Effect.none )

        FormStatusChanged val ->
            ( { model | formStatus = val }, Effect.none )

        SaveTournament ->
            let
                data =
                    { name = model.formName
                    , year = String.toInt model.formYear |> Maybe.withDefault 0
                    , numPreliminaryRounds = String.toInt model.formPrelimRounds |> Maybe.withDefault 4
                    , numEliminationRounds = String.toInt model.formElimRounds |> Maybe.withDefault 3
                    , status = model.formStatus
                    }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateTournament user.token id data GotSaveResponse

                        Nothing ->
                            Api.createTournament user.token data GotSaveResponse
            in
            ( { model | formSaving = True }
            , Effect.sendCmd cmd
            )

        GotSaveResponse (Ok tournament) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\t ->
                                    if t.id == tournament.id then
                                        tournament

                                    else
                                        t
                                )
                                model.tournaments

                        Nothing ->
                            model.tournaments ++ [ tournament ]
            in
            ( { model
                | tournaments = updatedList
                , showForm = False
                , editingId = Nothing
                , formSaving = False
              }
            , Effect.none
            )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save tournament." }
            , Effect.none
            )

        DeleteTournament id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteTournament user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | tournaments = List.filter (\t -> t.id /= id) model.tournaments
                , deleting = Nothing
              }
            , Effect.none
            )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete tournament." }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Tournaments"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Tournaments" ] ]
            , div [ Attr.class "level-right" ]
                [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                    [ text "New Tournament" ]
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
                        "Edit Tournament"

                    Nothing ->
                        "New Tournament"
                )
            ]
        , Html.form [ Events.onSubmit SaveTournament ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Name" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value model.formName
                                , Events.onInput FormNameChanged
                                , Attr.required True
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ Attr.class "column is-2" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Year" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.type_ "number"
                                , Attr.value model.formYear
                                , Events.onInput FormYearChanged
                                , Attr.required True
                                ]
                                []
                            ]
                        ]
                    ]
                ]
            , div [ Attr.class "columns" ]
                [ div [ Attr.class "column is-3" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Preliminary Rounds" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.type_ "number"
                                , Attr.value model.formPrelimRounds
                                , Events.onInput FormPrelimRoundsChanged
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ Attr.class "column is-3" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Elimination Rounds" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.type_ "number"
                                , Attr.value model.formElimRounds
                                , Events.onInput FormElimRoundsChanged
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ Attr.class "column is-3" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Status" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormStatusChanged ]
                                    [ option [ Attr.value "draft", Attr.selected (model.formStatus == "draft") ] [ text "Draft" ]
                                    , option [ Attr.value "registration", Attr.selected (model.formStatus == "registration") ] [ text "Registration" ]
                                    , option [ Attr.value "active", Attr.selected (model.formStatus == "active") ] [ text "Active" ]
                                    , option [ Attr.value "completed", Attr.selected (model.formStatus == "completed") ] [ text "Completed" ]
                                    ]
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
                , div [ Attr.class "control" ]
                    [ button [ Attr.class "button", Attr.type_ "button", Events.onClick CancelForm ]
                        [ text "Cancel" ]
                    ]
                ]
            ]
        ]


viewTable : Model -> Html Msg
viewTable model =
    if List.isEmpty model.tournaments then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No tournaments yet. Create one to get started." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Name" ]
                    , th [] [ text "Year" ]
                    , th [] [ text "Rounds" ]
                    , th [] [ text "Status" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody [] (List.map (viewRow model) model.tournaments)
            ]


viewRow : Model -> Tournament -> Html Msg
viewRow model t =
    tr []
        [ td [] [ text t.name ]
        , td [] [ text (String.fromInt t.year) ]
        , td [] [ text (String.fromInt t.numPreliminaryRounds ++ "P + " ++ String.fromInt t.numEliminationRounds ++ "E") ]
        , td [] [ viewStatusTag t.status ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditTournament t) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if model.deleting == Just t.id then
                            "button is-danger is-outlined is-loading"

                         else
                            "button is-danger is-outlined"
                        )
                    , Events.onClick (DeleteTournament t.id)
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]


viewStatusTag : String -> Html msg
viewStatusTag status =
    let
        tagClass =
            case status of
                "draft" ->
                    "tag is-light"

                "registration" ->
                    "tag is-info"

                "active" ->
                    "tag is-success"

                "completed" ->
                    "tag is-dark"

                _ ->
                    "tag"
    in
    span [ Attr.class tagClass ] [ text status ]
