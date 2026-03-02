module Pages.Admin.Courtrooms exposing (Model, Msg, page)

import Api exposing (Courtroom)
import Auth
import Courtroom
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


type alias CourtroomForm =
    { name : String, location : String }


type FormState
    = FormHidden
    | FormOpen FormContext CourtroomForm (List String)
    | FormSaving FormContext CourtroomForm


type BulkState
    = BulkIdle
    | BulkEditing String
    | BulkSaving String
    | BulkFailed String String



-- MODEL


type alias Model =
    { courtrooms : RemoteData (List Courtroom)
    , form : FormState
    , bulk : BulkState
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { courtrooms = Loading
      , form = FormHidden
      , bulk = BulkIdle
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
    | BulkTextChanged String
    | BulkImport
    | GotBulkResponse (Result Http.Error Courtroom)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotCourtrooms (Ok response) ->
            ( { model | courtrooms = Succeeded response.items }, Effect.none )

        GotCourtrooms (Err _) ->
            ( { model | courtrooms = Failed "Failed to load courtrooms." }, Effect.none )

        ShowCreateForm ->
            ( { model | form = FormOpen Creating { name = "", location = "" } [] }, Effect.none )

        EditCourtroom c ->
            ( { model | form = FormOpen (Editing c.id) { name = c.name, location = c.location } [] }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormLocationChanged val ->
            ( { model | form = updateFormField (\f -> { f | location = val }) model.form }, Effect.none )

        SaveCourtroom ->
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
                                            Api.updateCourtroom user.token id data GotSaveResponse

                                        Creating ->
                                            Api.createCourtroom user.token data GotSaveResponse
                            in
                            ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok courtroom) ->
            let
                updateCourtrooms context courtrooms =
                    case context of
                        Editing _ ->
                            List.map
                                (\c ->
                                    if c.id == courtroom.id then
                                        courtroom

                                    else
                                        c
                                )
                                courtrooms

                        Creating ->
                            courtrooms ++ [ courtroom ]
            in
            case model.form of
                FormSaving context _ ->
                    ( { model
                        | courtrooms = RemoteData.map (updateCourtrooms context) model.courtrooms
                        , form = FormHidden
                      }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData [ "Failed to save courtroom." ] }, Effect.none )

                _ ->
                    ( model, Effect.none )

        DeleteCourtroom id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteCourtroom user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | courtrooms = RemoteData.map (List.filter (\c -> c.id /= id)) model.courtrooms
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

        GotBulkResponse (Ok courtroom) ->
            ( { model
                | courtrooms = RemoteData.map (\list -> list ++ [ courtroom ]) model.courtrooms
                , bulk = BulkIdle
              }
            , Effect.none
            )

        GotBulkResponse (Err _) ->
            case model.bulk of
                BulkSaving val ->
                    ( { model | bulk = BulkFailed val "Failed to create some courtrooms." }, Effect.none )

                _ ->
                    ( { model | bulk = BulkFailed "" "Failed to create some courtrooms." }, Effect.none )



-- HELPERS


validateForm : CourtroomForm -> Result (List String) { name : String, location : String }
validateForm formData =
    let
        toStrings =
            List.map (\(Error msg) -> msg)

        nameValidation =
            Courtroom.nameFromString formData.name |> Result.mapError toStrings

        allErrors =
            case nameValidation of
                Err errs ->
                    errs

                Ok _ ->
                    []
    in
    if List.isEmpty allErrors then
        Ok { name = String.trim formData.name, location = formData.location }

    else
        Err allErrors


updateFormField : (CourtroomForm -> CourtroomForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData _ ->
            FormOpen context (transform formData) []

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
        ( { model | bulk = BulkFailed bulkText "No valid lines found. Format: Name, Location" }, Effect.none )

    else if errors > 0 then
        ( { model | bulk = BulkFailed bulkText (String.fromInt errors ++ " line(s) could not be parsed. Format: Name, Location") }, Effect.none )

    else
        ( { model | bulk = BulkSaving bulkText }
        , Effect.batch
            (List.map
                (\data -> Effect.sendCmd (Api.createCourtroom user.token data GotBulkResponse))
                parsed
            )
        )



-- BULK PARSING


parseBulkLine : String -> Maybe { name : String, location : String }
parseBulkLine line =
    case String.split "," line |> List.map String.trim of
        [ name, location ] ->
            if name /= "" then
                Just { name = name, location = location }

            else
                Nothing

        [ name ] ->
            if name /= "" then
                Just { name = name, location = "" }

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
        , viewForm model.form
        , viewBulkInput model.bulk
        , viewCourtrooms model.courtrooms model.deleting
        ]
    }


viewCourtrooms : RemoteData (List Courtroom) -> Maybe String -> Html Msg
viewCourtrooms courtrooms deleting =
    case courtrooms of
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

        FormOpen context formData errors ->
            viewFormBox context formData errors False

        FormSaving context formData ->
            viewFormBox context formData [] True


viewFormBox : FormContext -> CourtroomForm -> List String -> Bool -> Html Msg
viewFormBox context formData errors saving =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit Courtroom"

                    Creating ->
                        "New Courtroom"
                )
            ]
        , viewErrors errors
        , Html.form [ Events.onSubmit SaveCourtroom ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Name/Number" ]
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
                        [ label [ Attr.class "label" ] [ text "Location" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value formData.location
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
            [ text "One courtroom per line. Format: "
            , code [] [ text "Name, Location" ]
            , text " (location is optional)"
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ textarea
                    [ Attr.class "textarea"
                    , Attr.rows 6
                    , Attr.placeholder "Dept 1, 2nd Floor\nDept 2, 3rd Floor\nDept 3"
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


viewErrors : List String -> Html msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "notification is-danger is-light" ]
            [ ul [] (List.map (\e -> li [] [ text e ]) errors) ]


viewTable : List Courtroom -> Maybe String -> Html Msg
viewTable courtrooms deleting =
    if List.isEmpty courtrooms then
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
            , tbody [] (List.map (viewRow deleting) courtrooms)
            ]


viewRow : Maybe String -> Courtroom -> Html Msg
viewRow deleting c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.location ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditCourtroom c) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if deleting == Just c.id then
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
