module Pages.Admin.Courtrooms exposing (Model, Msg, page)

import Api exposing (Courtroom)
import Auth
import Courtroom
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
    { courtrooms : RemoteData String (List Courtroom)
    , form : FormState
    , bulk : BulkState
    , deleting : Maybe String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { courtrooms = Loading
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      }
    , Pb.adminList { collection = "courtrooms", tag = "courtrooms", filter = "", sort = "" }
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | ShowCreateForm
    | ShowBulkImport
    | EditCourtroom Courtroom
    | CancelForm
    | CancelBulk
    | FormNameChanged String
    | FormLocationChanged String
    | SaveCourtroom
    | DeleteCourtroom String
    | BulkTextChanged String
    | BulkImport


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "courtrooms" ->
                    case Pb.decodeList Api.courtroomDecoder value of
                        Ok items ->
                            ( { model | courtrooms = Success items }, Effect.none )

                        Err err ->
                            ( { model | courtrooms = Failure err }, Effect.none )

                Just "save-courtroom" ->
                    case Pb.decodeRecord Api.courtroomDecoder value of
                        Ok courtroom ->
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

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save courtroom." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-courtroom" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | courtrooms = RemoteData.map (List.filter (\c -> c.id /= id)) model.courtrooms
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                Just "bulk-courtroom" ->
                    case Pb.decodeRecord Api.courtroomDecoder value of
                        Ok courtroom ->
                            ( { model
                                | courtrooms = RemoteData.map (\list -> list ++ [ courtroom ]) model.courtrooms
                                , bulk = BulkIdle
                              }
                            , Effect.none
                            )

                        Err _ ->
                            case model.bulk of
                                BulkSaving val ->
                                    ( { model | bulk = BulkFailed val "Failed to create some courtrooms." }, Effect.none )

                                _ ->
                                    ( { model | bulk = BulkFailed "" "Failed to create some courtrooms." }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ShowCreateForm ->
            ( { model | form = FormOpen Creating { name = "", location = "" } [], bulk = BulkIdle }, Effect.none )

        ShowBulkImport ->
            ( { model | bulk = BulkEditing "", form = FormHidden }, Effect.none )

        EditCourtroom c ->
            ( { model | form = FormOpen (Editing c.id) { name = c.name, location = c.location } [], bulk = BulkIdle }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        CancelBulk ->
            ( { model | bulk = BulkIdle }, Effect.none )

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
                                effect =
                                    case context of
                                        Editing id ->
                                            Pb.adminUpdate { collection = "courtrooms", id = id, tag = "save-courtroom", body = Api.encodeCourtroom data }

                                        Creating ->
                                            Pb.adminCreate { collection = "courtrooms", tag = "save-courtroom", body = Api.encodeCourtroom data }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteCourtroom id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "courtrooms", id = id, tag = "delete-courtroom" }
            )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        BulkImport ->
            handleBulkImport model



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


handleBulkImport : Model -> ( Model, Effect Msg )
handleBulkImport model =
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
                (\data -> Pb.adminCreate { collection = "courtrooms", tag = "bulk-courtroom", body = Api.encodeCourtroom data })
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
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Courtrooms"
    , body =
        [ UI.titleBar
            { title = "Courtrooms"
            , actions =
                [ { label = "New Courtroom", msg = ShowCreateForm }
                , { label = "Bulk Import", msg = ShowBulkImport }
                ]
            }
        , viewForm model.form
        , viewBulkInput model.bulk
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.courtrooms of
        NotAsked ->
            UI.notAsked "Getting ready…"

        Loading ->
            UI.loading

        Failure err ->
            UI.error err

        Success [] ->
            UI.emptyState "No courtrooms yet. Add one to get started."

        Success courtrooms ->
            UI.dataTable
                { columns = [ "Name/Number", "Location", "Actions" ]
                , rows = courtrooms
                , rowView = viewRow model.deleting
                }


viewForm : FormState -> Html Msg
viewForm state =
    case state of
        FormHidden ->
            UI.empty

        FormOpen context formData errors ->
            viewFormCard context formData errors False

        FormSaving context formData ->
            viewFormCard context formData [] True


viewFormCard : FormContext -> CourtroomForm -> List String -> Bool -> Html Msg
viewFormCard context formData errors saving =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Courtroom"

                    Editing _ ->
                        "Edit Courtroom"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveCourtroom ]
                [ UI.formColumns
                    [ UI.textField
                        { label = "Name/Number"
                        , value = formData.name
                        , onInput = FormNameChanged
                        , required = True
                        }
                    , UI.textField
                        { label = "Location"
                        , value = formData.location
                        , onInput = FormLocationChanged
                        , required = False
                        }
                    ]
                , UI.actionRow
                    [ UI.primaryButton { label = "Save", loading = saving }
                    , UI.cancelButton CancelForm
                    ]
                ]
            ]
        ]


viewBulkInput : BulkState -> Html Msg
viewBulkInput state =
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
                        [ text "One courtroom per line. Format: "
                        , code [] [ text "Name, Location" ]
                        , text " (location is optional)"
                        ]
                    , UI.textareaField
                        { label = ""
                        , value = bulkText
                        , onInput = BulkTextChanged
                        , rows = 6
                        , placeholder = "Dept 1, 2nd Floor\nDept 2, 3rd Floor\nDept 3"
                        }
                    , case bulkError of
                        Just err ->
                            UI.error err

                        Nothing ->
                            UI.empty
                    , UI.actionRow
                        [ UI.loadingActionButton
                            { label = "Import"
                            , variant = "info"
                            , loading = saving
                            , disabled = String.trim bulkText == ""
                            , msg = BulkImport
                            }
                        , UI.cancelButton CancelBulk
                        ]
                    ]
                ]


viewRow : Maybe String -> Courtroom -> Html Msg
viewRow deleting c =
    tr []
        [ td [] [ text c.name ]
        , td [] [ text c.location ]
        , td []
            [ UI.buttonRow
                [ UI.rowActionButton
                    { label = "Edit"
                    , variant = "info"
                    , loading = False
                    , msg = EditCourtroom c
                    }
                , UI.rowActionButton
                    { label = "Delete"
                    , variant = "error"
                    , loading = deleting == Just c.id
                    , msg = DeleteCourtroom c.id
                    }
                ]
            ]
        ]
