module Pages.Admin.Schools exposing (Model, Msg, page)

import Api exposing (School)
import Auth
import District
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
import School
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


type alias SchoolForm =
    { name : String, district : String }


type FormState
    = FormHidden
    | FormOpen FormContext SchoolForm (List String)
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


init : () -> ( Model, Effect Msg )
init _ =
    ( { schools = Loading
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      }
    , Pb.adminList { collection = "schools", tag = "schools", filter = "", sort = "" }
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | ShowCreateForm
    | ShowBulkImport
    | EditSchool School
    | CancelForm
    | CancelBulk
    | FormNameChanged String
    | FormDistrictChanged String
    | SaveSchool
    | DeleteSchool String
    | BulkTextChanged String
    | BulkImport


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "schools" ->
                    case Pb.decodeList Api.schoolDecoder value of
                        Ok items ->
                            ( { model | schools = Succeeded items }, Effect.none )

                        Err err ->
                            ( { model | schools = Failed err }, Effect.none )

                Just "save-school" ->
                    case Pb.decodeRecord Api.schoolDecoder value of
                        Ok school ->
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

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save school." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-school" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | schools = RemoteData.map (List.filter (\s -> s.id /= id)) model.schools
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                Just "bulk-school" ->
                    case Pb.decodeRecord Api.schoolDecoder value of
                        Ok school ->
                            ( { model
                                | schools = RemoteData.map (\list -> list ++ [ school ]) model.schools
                                , bulk = BulkIdle
                              }
                            , Effect.none
                            )

                        Err _ ->
                            case model.bulk of
                                BulkSaving val ->
                                    ( { model | bulk = BulkFailed val "Failed to create some schools." }, Effect.none )

                                _ ->
                                    ( { model | bulk = BulkFailed "" "Failed to create some schools." }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ShowCreateForm ->
            ( { model | form = FormOpen Creating { name = "", district = "" } [], bulk = BulkIdle }, Effect.none )

        ShowBulkImport ->
            ( { model | bulk = BulkEditing "", form = FormHidden }, Effect.none )

        EditSchool s ->
            ( { model | form = FormOpen (Editing s.id) { name = s.name, district = s.district } [], bulk = BulkIdle }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        CancelBulk ->
            ( { model | bulk = BulkIdle }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormDistrictChanged val ->
            ( { model | form = updateFormField (\f -> { f | district = val }) model.form }, Effect.none )

        SaveSchool ->
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
                                            Pb.adminUpdate { collection = "schools", id = id, tag = "save-school", body = Api.encodeSchool data }

                                        Creating ->
                                            Pb.adminCreate { collection = "schools", tag = "save-school", body = Api.encodeSchool data }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteSchool id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "schools", id = id, tag = "delete-school" }
            )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        BulkImport ->
            handleBulkImport model



-- HELPERS


type alias ValidatedSchool =
    { name : String, district : String }


validateForm : SchoolForm -> Result (List String) ValidatedSchool
validateForm formData =
    let
        toStrings =
            List.map (\(Error msg) -> msg)

        nameValidation =
            School.nameFromString formData.name |> Result.mapError toStrings

        districtValidation =
            if String.trim formData.district == "" then
                Ok ()

            else
                District.nameFromString formData.district
                    |> Result.map (\_ -> ())
                    |> Result.mapError toStrings

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
                [ nameValidation |> Result.map (\_ -> ())
                , districtValidation
                ]
    in
    if List.isEmpty allErrors then
        Ok
            { name = String.trim formData.name
            , district = String.trim formData.district
            }

    else
        Err allErrors


updateFormField : (SchoolForm -> SchoolForm) -> FormState -> FormState
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
        ( { model | bulk = BulkFailed bulkText "No valid lines found. Format: Name, District" }, Effect.none )

    else if errors > 0 then
        ( { model | bulk = BulkFailed bulkText (String.fromInt errors ++ " line(s) could not be parsed. Format: Name, District") }, Effect.none )

    else
        ( { model | bulk = BulkSaving bulkText }
        , Effect.batch
            (List.map
                (\data -> Pb.adminCreate { collection = "schools", tag = "bulk-school", body = Api.encodeSchool data })
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
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Schools"
    , body =
        [ UI.titleBar
            { title = "Schools"
            , actions =
                [ { label = "New School", msg = ShowCreateForm }
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
    case model.schools of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded [] ->
            UI.emptyState "No schools yet. Add one to get started."

        Succeeded schools ->
            UI.dataTable
                { columns = [ "Name", "District", "Actions" ]
                , rows = schools
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


viewFormCard : FormContext -> SchoolForm -> List String -> Bool -> Html Msg
viewFormCard context formData errors saving =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New School"

                    Editing _ ->
                        "Edit School"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveSchool ]
                [ UI.formColumns
                    [ UI.textField
                        { label = "Name"
                        , value = formData.name
                        , onInput = FormNameChanged
                        , required = True
                        }
                    , UI.textField
                        { label = "District"
                        , value = formData.district
                        , onInput = FormDistrictChanged
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
                        [ text "One school per line. Format: "
                        , code [] [ text "Name, District" ]
                        , text " (district is optional)"
                        ]
                    , UI.textareaField
                        { label = ""
                        , value = bulkText
                        , onInput = BulkTextChanged
                        , rows = 6
                        , placeholder = "Lincoln High, Riverside USD\nKennedy Middle, Alvord USD\nNorth High"
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
                            , Attr.disabled (saving || String.trim bulkText == "")
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


viewRow : Maybe String -> School -> Html Msg
viewRow deleting s =
    tr []
        [ td [] [ text s.name ]
        , td [] [ text s.district ]
        , td []
            [ div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-outline btn-info"
                    , Events.onClick (EditSchool s)
                    ]
                    [ text "Edit" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-error"
                    , Events.onClick (DeleteSchool s.id)
                    , Attr.disabled (deleting == Just s.id)
                    ]
                    (if deleting == Just s.id then
                        [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                     else
                        [ text "Delete" ]
                    )
                ]
            ]
        ]
