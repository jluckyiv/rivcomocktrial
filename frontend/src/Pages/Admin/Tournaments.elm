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
import RemoteData exposing (RemoteData(..))
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



-- TYPES


type FormContext
    = Creating
    | Editing String


type alias TournamentForm =
    { name : String
    , year : String
    , prelimRounds : String
    , elimRounds : String
    , status : String
    }


type FormState
    = FormHidden
    | FormOpen FormContext TournamentForm (Maybe String)
    | FormSaving FormContext TournamentForm



-- MODEL


type alias Model =
    { tournaments : RemoteData (List Tournament)
    , form : FormState
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { tournaments = Loading
      , form = FormHidden
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
            ( { model | tournaments = Succeeded response.items }, Effect.none )

        GotTournaments (Err _) ->
            ( { model | tournaments = Failed "Failed to load tournaments." }, Effect.none )

        ShowCreateForm ->
            ( { model
                | form =
                    FormOpen Creating
                        { name = ""
                        , year = ""
                        , prelimRounds = "4"
                        , elimRounds = "3"
                        , status = "draft"
                        }
                        Nothing
              }
            , Effect.none
            )

        EditTournament t ->
            ( { model
                | form =
                    FormOpen (Editing t.id)
                        { name = t.name
                        , year = String.fromInt t.year
                        , prelimRounds = String.fromInt t.numPreliminaryRounds
                        , elimRounds = String.fromInt t.numEliminationRounds
                        , status = t.status
                        }
                        Nothing
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormYearChanged val ->
            ( { model | form = updateFormField (\f -> { f | year = val }) model.form }, Effect.none )

        FormPrelimRoundsChanged val ->
            ( { model | form = updateFormField (\f -> { f | prelimRounds = val }) model.form }, Effect.none )

        FormElimRoundsChanged val ->
            ( { model | form = updateFormField (\f -> { f | elimRounds = val }) model.form }, Effect.none )

        FormStatusChanged val ->
            ( { model | form = updateFormField (\f -> { f | status = val }) model.form }, Effect.none )

        SaveTournament ->
            case model.form of
                FormOpen context formData _ ->
                    let
                        data =
                            { name = formData.name
                            , year = String.toInt formData.year |> Maybe.withDefault 0
                            , numPreliminaryRounds = String.toInt formData.prelimRounds |> Maybe.withDefault 4
                            , numEliminationRounds = String.toInt formData.elimRounds |> Maybe.withDefault 3
                            , status = formData.status
                            }

                        cmd =
                            case context of
                                Editing id ->
                                    Api.updateTournament user.token id data GotSaveResponse

                                Creating ->
                                    Api.createTournament user.token data GotSaveResponse
                    in
                    ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok tournament) ->
            let
                updateTournaments context tournaments =
                    case context of
                        Editing _ ->
                            List.map
                                (\t ->
                                    if t.id == tournament.id then
                                        tournament

                                    else
                                        t
                                )
                                tournaments

                        Creating ->
                            tournaments ++ [ tournament ]
            in
            case model.form of
                FormSaving context _ ->
                    ( { model
                        | tournaments = RemoteData.map (updateTournaments context) model.tournaments
                        , form = FormHidden
                      }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData (Just "Failed to save tournament.") }, Effect.none )

                _ ->
                    ( model, Effect.none )

        DeleteTournament id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteTournament user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | tournaments = RemoteData.map (List.filter (\t -> t.id /= id)) model.tournaments
                , deleting = Nothing
              }
            , Effect.none
            )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing }, Effect.none )



-- HELPERS


updateFormField : (TournamentForm -> TournamentForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData error ->
            FormOpen context (transform formData) error

        _ ->
            state



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
        , viewForm model.form
        , viewTournaments model.tournaments model.deleting
        ]
    }


viewTournaments : RemoteData (List Tournament) -> Maybe String -> Html Msg
viewTournaments tournaments deleting =
    case tournaments of
        NotAsked ->
            text ""

        Loading ->
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

        Failed err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Succeeded list ->
            viewTable list deleting


viewForm : FormState -> Html Msg
viewForm state =
    case state of
        FormHidden ->
            text ""

        FormOpen context formData error ->
            viewFormBox context formData error False

        FormSaving context formData ->
            viewFormBox context formData Nothing True


viewFormBox : FormContext -> TournamentForm -> Maybe String -> Bool -> Html Msg
viewFormBox context formData error saving =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit Tournament"

                    Creating ->
                        "New Tournament"
                )
            ]
        , case error of
            Just err ->
                div [ Attr.class "notification is-danger is-light" ] [ text err ]

            Nothing ->
                text ""
        , Html.form [ Events.onSubmit SaveTournament ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Name" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value formData.name
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
                                , Attr.value formData.year
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
                                , Attr.value formData.prelimRounds
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
                                , Attr.value formData.elimRounds
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
                                    [ option [ Attr.value "draft", Attr.selected (formData.status == "draft") ] [ text "Draft" ]
                                    , option [ Attr.value "registration", Attr.selected (formData.status == "registration") ] [ text "Registration" ]
                                    , option [ Attr.value "active", Attr.selected (formData.status == "active") ] [ text "Active" ]
                                    , option [ Attr.value "completed", Attr.selected (formData.status == "completed") ] [ text "Completed" ]
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


viewTable : List Tournament -> Maybe String -> Html Msg
viewTable tournaments deleting =
    if List.isEmpty tournaments then
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
            , tbody [] (List.map (viewRow deleting) tournaments)
            ]


viewRow : Maybe String -> Tournament -> Html Msg
viewRow deleting t =
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
                        (if deleting == Just t.id then
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
