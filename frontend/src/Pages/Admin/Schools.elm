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
import RemoteData exposing (RemoteData(..))
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



-- TYPES


type FormContext
    = Creating
    | Editing String


type alias SchoolForm =
    { name : String, district : String }


type FormState
    = FormHidden
    | FormOpen FormContext SchoolForm (Maybe String)
    | FormSaving FormContext SchoolForm


type BulkState
    = BulkIdle
    | BulkEditing String
    | BulkSaving String
    | BulkFailed String String



-- MODEL


type alias Model =
    { schools : RemoteData (List School)
    , form : FormState
    , bulk : BulkState
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { schools = Loading
      , form = FormHidden
      , bulk = BulkIdle
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
    | BulkTextChanged String
    | BulkImport
    | GotBulkResponse (Result Http.Error School)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotSchools (Ok response) ->
            ( { model | schools = Succeeded response.items }, Effect.none )

        GotSchools (Err _) ->
            ( { model | schools = Failed "Failed to load schools." }, Effect.none )

        ShowCreateForm ->
            ( { model | form = FormOpen Creating { name = "", district = "" } Nothing }, Effect.none )

        EditSchool s ->
            ( { model | form = FormOpen (Editing s.id) { name = s.name, district = s.district } Nothing }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormDistrictChanged val ->
            ( { model | form = updateFormField (\f -> { f | district = val }) model.form }, Effect.none )

        SaveSchool ->
            case model.form of
                FormOpen context formData _ ->
                    let
                        data =
                            { name = formData.name, district = formData.district }

                        cmd =
                            case context of
                                Editing id ->
                                    Api.updateSchool user.token id data GotSaveResponse

                                Creating ->
                                    Api.createSchool user.token data GotSaveResponse
                    in
                    ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok school) ->
            let
                updateSchools context schools =
                    case context of
                        Editing _ ->
                            List.map
                                (\s ->
                                    if s.id == school.id then
                                        school

                                    else
                                        s
                                )
                                schools

                        Creating ->
                            schools ++ [ school ]
            in
            case model.form of
                FormSaving context _ ->
                    ( { model
                        | schools = RemoteData.map (updateSchools context) model.schools
                        , form = FormHidden
                      }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData (Just "Failed to save school.") }, Effect.none )

                _ ->
                    ( model, Effect.none )

        DeleteSchool id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteSchool user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | schools = RemoteData.map (List.filter (\s -> s.id /= id)) model.schools
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

        GotBulkResponse (Ok school) ->
            ( { model
                | schools = RemoteData.map (\list -> list ++ [ school ]) model.schools
                , bulk = BulkIdle
              }
            , Effect.none
            )

        GotBulkResponse (Err _) ->
            case model.bulk of
                BulkSaving val ->
                    ( { model | bulk = BulkFailed val "Failed to create some schools." }, Effect.none )

                _ ->
                    ( { model | bulk = BulkFailed "" "Failed to create some schools." }, Effect.none )



-- HELPERS


updateFormField : (SchoolForm -> SchoolForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData error ->
            FormOpen context (transform formData) error

        _ ->
            state


handleBulkImport : Auth.User -> Model -> ( Model, Effect Msg )
handleBulkImport user model =
    let
        bulkText =
            case model.bulk of
                BulkEditing val ->
                    val

                BulkFailed val _ ->
                    val

                _ ->
                    ""

        lines =
            String.lines bulkText
                |> List.map String.trim
                |> List.filter (\l -> l /= "")

        parsed =
            List.filterMap parseBulkLine lines

        errors =
            List.length lines - List.length parsed
    in
    if List.isEmpty parsed then
        ( { model | bulk = BulkFailed bulkText "No valid lines found. Format: Name, District" }, Effect.none )

    else if errors > 0 then
        ( { model | bulk = BulkFailed bulkText (String.fromInt errors ++ " line(s) could not be parsed. Format: Name, District") }, Effect.none )

    else
        ( { model | bulk = BulkSaving bulkText }
        , Effect.batch
            (List.map
                (\data -> Effect.sendCmd (Api.createSchool user.token data GotBulkResponse))
                parsed
            )
        )



-- BULK PARSING


parseBulkLine : String -> Maybe { name : String, district : String }
parseBulkLine line =
    case String.split "," line |> List.map String.trim of
        [ name, district ] ->
            if name /= "" then
                Just { name = name, district = district }

            else
                Nothing

        [ name ] ->
            if name /= "" then
                Just { name = name, district = "" }

            else
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
        , viewForm model.form
        , viewBulkInput model.bulk
        , viewSchools model.schools model.deleting
        ]
    }


viewSchools : RemoteData (List School) -> Maybe String -> Html Msg
viewSchools schools deleting =
    case schools of
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


viewFormBox : FormContext -> SchoolForm -> Maybe String -> Bool -> Html Msg
viewFormBox context formData error saving =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit School"

                    Creating ->
                        "New School"
                )
            ]
        , case error of
            Just err ->
                div [ Attr.class "notification is-danger is-light" ] [ text err ]

            Nothing ->
                text ""
        , Html.form [ Events.onSubmit SaveSchool ]
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
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "District" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value formData.district
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


viewBulkInput : BulkState -> Html Msg
viewBulkInput state =
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
            [ text "One school per line. Format: "
            , code [] [ text "Name, District" ]
            , text " (district is optional)"
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ textarea
                    [ Attr.class "textarea"
                    , Attr.rows 6
                    , Attr.placeholder "Lincoln High, Riverside USD\nKennedy Middle, Alvord USD\nNorth High"
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
                , Attr.disabled (String.trim bulkText == "")
                ]
                [ text "Import" ]
            ]
        ]


viewTable : List School -> Maybe String -> Html Msg
viewTable schools deleting =
    if List.isEmpty schools then
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
            , tbody [] (List.map (viewRow deleting) schools)
            ]


viewRow : Maybe String -> School -> Html Msg
viewRow deleting s =
    tr []
        [ td [] [ text s.name ]
        , td [] [ text s.district ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditSchool s) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if deleting == Just s.id then
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
