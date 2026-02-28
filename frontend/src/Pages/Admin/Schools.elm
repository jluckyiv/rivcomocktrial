module Pages.Admin.Schools exposing (Model, Msg, page)

import Api exposing (School)
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
    { schools : List School
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formName : String
    , formDistrict : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { schools = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formName = ""
      , formDistrict = ""
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      }
    , Effect.sendCmd (Api.listSchools user.token GotSchools)
    )



-- UPDATE


type Msg
    = GotSchools (Result Http.Error (Api.ListResponse School))
    | ShowCreateForm
    | EditSchool School
    | CancelForm
    | FormNameChanged String
    | FormDistrictChanged String
    | SaveSchool
    | GotSaveResponse (Result Http.Error School)
    | DeleteSchool String
    | GotDeleteResponse String (Result Http.Error ())


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotSchools (Ok response) ->
            ( { model | schools = response.items, loading = False }, Effect.none )

        GotSchools (Err _) ->
            ( { model | loading = False, error = Just "Failed to load schools." }, Effect.none )

        ShowCreateForm ->
            ( { model | showForm = True, editingId = Nothing, formName = "", formDistrict = "" }, Effect.none )

        EditSchool s ->
            ( { model | showForm = True, editingId = Just s.id, formName = s.name, formDistrict = s.district }, Effect.none )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }, Effect.none )

        FormNameChanged val ->
            ( { model | formName = val }, Effect.none )

        FormDistrictChanged val ->
            ( { model | formDistrict = val }, Effect.none )

        SaveSchool ->
            let
                data =
                    { name = model.formName, district = model.formDistrict }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateSchool user.token id data GotSaveResponse

                        Nothing ->
                            Api.createSchool user.token data GotSaveResponse
            in
            ( { model | formSaving = True }, Effect.sendCmd cmd )

        GotSaveResponse (Ok school) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\s ->
                                    if s.id == school.id then
                                        school

                                    else
                                        s
                                )
                                model.schools

                        Nothing ->
                            model.schools ++ [ school ]
            in
            ( { model | schools = updatedList, showForm = False, editingId = Nothing, formSaving = False }, Effect.none )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save school." }, Effect.none )

        DeleteSchool id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteSchool user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model | schools = List.filter (\s -> s.id /= id) model.schools, deleting = Nothing }, Effect.none )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete school." }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Schools"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Schools" ] ]
            , div [ Attr.class "level-right" ]
                [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                    [ text "New School" ]
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
                        "Edit School"

                    Nothing ->
                        "New School"
                )
            ]
        , Html.form [ Events.onSubmit SaveSchool ]
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
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "District" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value model.formDistrict
                                , Events.onInput FormDistrictChanged
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
    if List.isEmpty model.schools then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No schools yet. Add one to get started." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Name" ]
                    , th [] [ text "District" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody [] (List.map (viewRow model) model.schools)
            ]


viewRow : Model -> School -> Html Msg
viewRow model s =
    tr []
        [ td [] [ text s.name ]
        , td [] [ text s.district ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditSchool s) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if model.deleting == Just s.id then
                            "button is-danger is-outlined is-loading"

                         else
                            "button is-danger is-outlined"
                        )
                    , Events.onClick (DeleteSchool s.id)
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]
