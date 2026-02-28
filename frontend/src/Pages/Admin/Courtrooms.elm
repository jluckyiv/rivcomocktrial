module Pages.Admin.Courtrooms exposing (Model, Msg, page)

import Api exposing (Courtroom)
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
    { courtrooms : List Courtroom
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formName : String
    , formLocation : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { courtrooms = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formName = ""
      , formLocation = ""
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      }
    , Effect.sendCmd (Api.listCourtrooms user.token GotCourtrooms)
    )



-- UPDATE


type Msg
    = GotCourtrooms (Result Http.Error (Api.ListResponse Courtroom))
    | ShowCreateForm
    | EditCourtroom Courtroom
    | CancelForm
    | FormNameChanged String
    | FormLocationChanged String
    | SaveCourtroom
    | GotSaveResponse (Result Http.Error Courtroom)
    | DeleteCourtroom String
    | GotDeleteResponse String (Result Http.Error ())


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotCourtrooms (Ok response) ->
            ( { model | courtrooms = response.items, loading = False }, Effect.none )

        GotCourtrooms (Err _) ->
            ( { model | loading = False, error = Just "Failed to load courtrooms." }, Effect.none )

        ShowCreateForm ->
            ( { model | showForm = True, editingId = Nothing, formName = "", formLocation = "" }, Effect.none )

        EditCourtroom c ->
            ( { model | showForm = True, editingId = Just c.id, formName = c.name, formLocation = c.location }, Effect.none )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }, Effect.none )

        FormNameChanged val ->
            ( { model | formName = val }, Effect.none )

        FormLocationChanged val ->
            ( { model | formLocation = val }, Effect.none )

        SaveCourtroom ->
            let
                data =
                    { name = model.formName, location = model.formLocation }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateCourtroom user.token id data GotSaveResponse

                        Nothing ->
                            Api.createCourtroom user.token data GotSaveResponse
            in
            ( { model | formSaving = True }, Effect.sendCmd cmd )

        GotSaveResponse (Ok courtroom) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\c ->
                                    if c.id == courtroom.id then
                                        courtroom

                                    else
                                        c
                                )
                                model.courtrooms

                        Nothing ->
                            model.courtrooms ++ [ courtroom ]
            in
            ( { model | courtrooms = updatedList, showForm = False, editingId = Nothing, formSaving = False }, Effect.none )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save courtroom." }, Effect.none )

        DeleteCourtroom id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteCourtroom user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model | courtrooms = List.filter (\c -> c.id /= id) model.courtrooms, deleting = Nothing }, Effect.none )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete courtroom." }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Courtrooms"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Courtrooms" ] ]
            , div [ Attr.class "level-right" ]
                [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                    [ text "New Courtroom" ]
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
                        "Edit Courtroom"

                    Nothing ->
                        "New Courtroom"
                )
            ]
        , Html.form [ Events.onSubmit SaveCourtroom ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Name/Number" ]
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
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Location" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value model.formLocation
                                , Events.onInput FormLocationChanged
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
    if List.isEmpty model.courtrooms then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No courtrooms yet. Add one to get started." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Name/Number" ]
                    , th [] [ text "Location" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody []
                (List.map
                    (\c ->
                        tr []
                            [ td [] [ text c.name ]
                            , td [] [ text c.location ]
                            , td []
                                [ div [ Attr.class "buttons are-small" ]
                                    [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditCourtroom c) ]
                                        [ text "Edit" ]
                                    , button
                                        [ Attr.class
                                            (if model.deleting == Just c.id then
                                                "button is-danger is-outlined is-loading"

                                             else
                                                "button is-danger is-outlined"
                                            )
                                        , Events.onClick (DeleteCourtroom c.id)
                                        ]
                                        [ text "Delete" ]
                                    ]
                                ]
                            ]
                    )
                    model.courtrooms
                )
            ]
