module Pages.Admin.Students exposing (Model, Msg, page)

import Api exposing (School, Student)
import Auth
import Effect exposing (Effect)
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


type alias StudentForm =
    { name : String, school : String, pronouns : String }


type FormState
    = FormHidden
    | FormOpen FormContext StudentForm (List String)
    | FormSaving FormContext StudentForm


type BulkState
    = BulkIdle
    | BulkEditing String
    | BulkSaving String
    | BulkFailed String String



-- MODEL


type alias Model =
    { students : RemoteData (List Student)
    , schools : List School
    , form : FormState
    , bulk : BulkState
    , deleting : Maybe String
    , filterSchool : String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { students = Loading
      , schools = []
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      , filterSchool = ""
      }
    , Effect.batch
        [ Pb.adminList { collection = "students", tag = "students", filter = "", sort = "" }
        , Pb.adminList { collection = "schools", tag = "schools", filter = "", sort = "" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterSchoolChanged String
    | ShowCreateForm
    | ShowBulkImport
    | EditStudent Student
    | CancelForm
    | CancelBulk
    | FormNameChanged String
    | FormSchoolChanged String
    | FormPronounsChanged String
    | SaveStudent
    | DeleteStudent String
    | BulkTextChanged String
    | BulkImport


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "students" ->
                    case Pb.decodeList Api.studentDecoder value of
                        Ok items ->
                            ( { model | students = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | students = Failed "Failed to load students." }, Effect.none )

                Just "schools" ->
                    case Pb.decodeList Api.schoolDecoder value of
                        Ok items ->
                            ( { model | schools = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-student" ->
                    case Pb.decodeRecord Api.studentDecoder value of
                        Ok student ->
                            let
                                updateStudents context students =
                                    case context of
                                        Editing _ ->
                                            List.map
                                                (\s ->
                                                    if s.id == student.id then
                                                        student

                                                    else
                                                        s
                                                )
                                                students

                                        Creating ->
                                            students ++ [ student ]
                            in
                            case model.form of
                                FormSaving context _ ->
                                    ( { model
                                        | students = RemoteData.map (updateStudents context) model.students
                                        , form = FormHidden
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save student." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-student" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | students = RemoteData.map (List.filter (\s -> s.id /= id)) model.students
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                Just "bulk-student" ->
                    case Pb.decodeRecord Api.studentDecoder value of
                        Ok student ->
                            ( { model
                                | students = RemoteData.map (\list -> list ++ [ student ]) model.students
                                , bulk = BulkIdle
                              }
                            , Effect.none
                            )

                        Err _ ->
                            case model.bulk of
                                BulkSaving val ->
                                    ( { model | bulk = BulkFailed val "Failed to create some students." }, Effect.none )

                                _ ->
                                    ( { model | bulk = BulkFailed "" "Failed to create some students." }, Effect.none )

                _ ->
                    ( model, Effect.none )

        FilterSchoolChanged val ->
            ( { model | filterSchool = val }, Effect.none )

        ShowCreateForm ->
            ( { model
                | form = FormOpen Creating { name = "", school = model.filterSchool, pronouns = "" } []
                , bulk = BulkIdle
              }
            , Effect.none
            )

        ShowBulkImport ->
            ( { model | bulk = BulkEditing "", form = FormHidden }, Effect.none )

        EditStudent s ->
            ( { model | form = FormOpen (Editing s.id) { name = s.name, school = s.school, pronouns = Maybe.withDefault "" s.pronouns } [], bulk = BulkIdle }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        CancelBulk ->
            ( { model | bulk = BulkIdle }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormSchoolChanged val ->
            ( { model | form = updateFormField (\f -> { f | school = val }) model.form }, Effect.none )

        FormPronounsChanged val ->
            ( { model | form = updateFormField (\f -> { f | pronouns = val }) model.form }, Effect.none )

        SaveStudent ->
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
                                            Pb.adminUpdate
                                                { collection = "students"
                                                , id = id
                                                , tag = "save-student"
                                                , body = Api.encodeStudent data
                                                }

                                        Creating ->
                                            Pb.adminCreate
                                                { collection = "students"
                                                , tag = "save-student"
                                                , body = Api.encodeStudent data
                                                }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteStudent id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "students", id = id, tag = "delete-student" }
            )

        BulkTextChanged val ->
            ( { model | bulk = BulkEditing val }, Effect.none )

        BulkImport ->
            handleBulkImport model



-- HELPERS


validateForm : StudentForm -> Result (List String) { name : String, school : String, pronouns : Maybe String }
validateForm formData =
    let
        errors =
            []
                |> addErrorIf (String.trim formData.name == "") "Name is required"
                |> addErrorIf (String.trim formData.school == "") "School is required"

        pronouns =
            if String.trim formData.pronouns == "" then
                Nothing

            else
                Just (String.trim formData.pronouns)
    in
    if List.isEmpty errors then
        Ok { name = formData.name, school = formData.school, pronouns = pronouns }

    else
        Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors


updateFormField : (StudentForm -> StudentForm) -> FormState -> FormState
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
            List.filterMap (parseBulkLine model.schools) lines

        errors =
            List.length lines - List.length parsed
    in
    if List.isEmpty parsed then
        ( { model | bulk = BulkFailed bulkText "No valid lines found. Format: Name, School Name" }, Effect.none )

    else if errors > 0 then
        ( { model | bulk = BulkFailed bulkText (String.fromInt errors ++ " line(s) could not be parsed. Check school names match exactly.") }, Effect.none )

    else
        ( { model | bulk = BulkSaving bulkText }
        , Effect.batch
            (List.map
                (\data ->
                    Pb.adminCreate
                        { collection = "students"
                        , tag = "bulk-student"
                        , body = Api.encodeStudent data
                        }
                )
                parsed
            )
        )



-- BULK PARSING


parseBulkLine : List School -> String -> Maybe { name : String, school : String, pronouns : Maybe String }
parseBulkLine schools line =
    case String.split "," line |> List.map String.trim of
        [ name, schoolName ] ->
            if name /= "" then
                let
                    schoolId =
                        schools
                            |> List.filter (\s -> String.toLower s.name == String.toLower schoolName)
                            |> List.head
                            |> Maybe.map .id
                            |> Maybe.withDefault ""
                in
                if schoolId /= "" then
                    Just { name = name, school = schoolId, pronouns = Nothing }

                else
                    Nothing

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
    { title = "Students"
    , body =
        [ UI.titleBar
            { title = "Students"
            , actions =
                [ { label = "New Student", msg = ShowCreateForm }
                , { label = "Bulk Import", msg = ShowBulkImport }
                ]
            }
        , UI.filterSelect
            { label = "School:"
            , value = model.filterSchool
            , onInput = FilterSchoolChanged
            , options =
                { value = "", label = "All Schools" }
                    :: List.map (\s -> { value = s.id, label = s.name }) model.schools
            }
        , viewForm model.form model.schools
        , viewBulkInput model.bulk
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.students of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded students ->
            let
                filtered =
                    if model.filterSchool == "" then
                        students

                    else
                        List.filter (\s -> s.school == model.filterSchool) students

                schoolName id =
                    List.filter (\s -> s.id == id) model.schools
                        |> List.head
                        |> Maybe.map .name
                        |> Maybe.withDefault id
            in
            if List.isEmpty filtered then
                UI.emptyState "No students yet."

            else
                UI.dataTable
                    { columns = [ "Name", "School", "Actions" ]
                    , rows = filtered
                    , rowView = viewRow model.deleting schoolName
                    }


viewForm : FormState -> List School -> Html Msg
viewForm state schools =
    case state of
        FormHidden ->
            UI.empty

        FormOpen context formData errors ->
            viewFormCard context formData errors False schools

        FormSaving context formData ->
            viewFormCard context formData [] True schools


viewFormCard : FormContext -> StudentForm -> List String -> Bool -> List School -> Html Msg
viewFormCard context formData errors saving schools =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Student"

                    Editing _ ->
                        "Edit Student"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveStudent ]
                [ UI.formColumns
                    [ UI.textField
                        { label = "Name"
                        , value = formData.name
                        , onInput = FormNameChanged
                        , required = True
                        }
                    , UI.selectField
                        { label = "School"
                        , value = formData.school
                        , onInput = FormSchoolChanged
                        , options =
                            { value = "", label = "Select school..." }
                                :: List.map (\s -> { value = s.id, label = s.name }) schools
                        }
                    , UI.textField
                        { label = "Pronouns"
                        , value = formData.pronouns
                        , onInput = FormPronounsChanged
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
                        [ text "One student per line. Format: "
                        , code [] [ text "Name, School Name" ]
                        , text " (school name must match exactly)"
                        ]
                    , UI.textareaField
                        { label = ""
                        , value = bulkText
                        , onInput = BulkTextChanged
                        , rows = 6
                        , placeholder = "Jane Doe, Lincoln High\nJohn Smith, Lincoln High\nAlex Johnson, Kennedy Middle"
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


viewRow : Maybe String -> (String -> String) -> Student -> Html Msg
viewRow deleting schoolName s =
    tr []
        [ td [] [ text s.name ]
        , td [] [ text (schoolName s.school) ]
        , td []
            [ UI.buttonRow
                [ UI.rowActionButton
                    { label = "Edit"
                    , variant = "info"
                    , loading = False
                    , msg = EditStudent s
                    }
                , UI.rowActionButton
                    { label = "Delete"
                    , variant = "error"
                    , loading = deleting == Just s.id
                    , msg = DeleteStudent s.id
                    }
                ]
            ]
        ]
