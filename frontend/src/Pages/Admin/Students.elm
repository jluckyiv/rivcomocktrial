module Pages.Admin.Students exposing (Model, Msg, page)

import Api exposing (School, Student)
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


type alias StudentForm =
    { name : String, school : String }


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


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { students = Loading
      , schools = []
      , form = FormHidden
      , bulk = BulkIdle
      , deleting = Nothing
      , filterSchool = ""
      }
    , Effect.batch
        [ Effect.sendCmd (Api.listStudents user.token GotStudents)
        , Effect.sendCmd (Api.listSchools user.token GotSchools)
        ]
    )



-- UPDATE


type Msg
    = GotStudents (Result Http.Error (Api.ListResponse Student))
    | GotSchools (Result Http.Error (Api.ListResponse School))
    | FilterSchoolChanged String
    | ShowCreateForm
    | EditStudent Student
    | CancelForm
    | FormNameChanged String
    | FormSchoolChanged String
    | SaveStudent
    | GotSaveResponse (Result Http.Error Student)
    | DeleteStudent String
    | GotDeleteResponse String (Result Http.Error ())
    | BulkTextChanged String
    | BulkImport
    | GotBulkResponse (Result Http.Error Student)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotStudents (Ok response) ->
            ( { model | students = Succeeded response.items }, Effect.none )

        GotStudents (Err _) ->
            ( { model | students = Failed "Failed to load students." }, Effect.none )

        GotSchools (Ok response) ->
            ( { model | schools = response.items }, Effect.none )

        GotSchools (Err _) ->
            ( model, Effect.none )

        FilterSchoolChanged val ->
            ( { model | filterSchool = val }, Effect.none )

        ShowCreateForm ->
            ( { model | form = FormOpen Creating { name = "", school = model.filterSchool } [] }, Effect.none )

        EditStudent s ->
            ( { model | form = FormOpen (Editing s.id) { name = s.name, school = s.school } [] }, Effect.none )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormSchoolChanged val ->
            ( { model | form = updateFormField (\f -> { f | school = val }) model.form }, Effect.none )

        SaveStudent ->
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
                                            Api.updateStudent user.token id data GotSaveResponse

                                        Creating ->
                                            Api.createStudent user.token data GotSaveResponse
                            in
                            ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok student) ->
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

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData [ "Failed to save student." ] }, Effect.none )

                _ ->
                    ( model, Effect.none )

        DeleteStudent id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteStudent user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | students = RemoteData.map (List.filter (\s -> s.id /= id)) model.students
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

        GotBulkResponse (Ok student) ->
            ( { model
                | students = RemoteData.map (\list -> list ++ [ student ]) model.students
                , bulk = BulkIdle
              }
            , Effect.none
            )

        GotBulkResponse (Err _) ->
            case model.bulk of
                BulkSaving val ->
                    ( { model | bulk = BulkFailed val "Failed to create some students." }, Effect.none )

                _ ->
                    ( { model | bulk = BulkFailed "" "Failed to create some students." }, Effect.none )



-- HELPERS


validateForm : StudentForm -> Result (List String) { name : String, school : String }
validateForm formData =
    let
        errors =
            []
                |> addErrorIf (String.trim formData.name == "") "Name is required"
                |> addErrorIf (String.trim formData.school == "") "School is required"
    in
    if List.isEmpty errors then
        Ok { name = formData.name, school = formData.school }

    else
        Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition error errors =
    if condition then
        errors ++ [ error ]

    else
        errors


updateFormField : (StudentForm -> StudentForm) -> FormState -> FormState
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
                (\data -> Effect.sendCmd (Api.createStudent user.token data GotBulkResponse))
                parsed
            )
        )



-- BULK PARSING


parseBulkLine : List School -> String -> Maybe { name : String, school : String }
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
                    Just { name = name, school = schoolId }

                else
                    Nothing

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
    { title = "Students"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Students" ] ]
            , div [ Attr.class "level-right" ]
                [ div [ Attr.class "field has-addons" ]
                    [ div [ Attr.class "control" ]
                        [ div [ Attr.class "select" ]
                            [ select [ Events.onInput FilterSchoolChanged ]
                                (option [ Attr.value "" ] [ text "All Schools" ]
                                    :: List.map
                                        (\s ->
                                            option [ Attr.value s.id, Attr.selected (model.filterSchool == s.id) ]
                                                [ text s.name ]
                                        )
                                        model.schools
                                )
                            ]
                        ]
                    , div [ Attr.class "control" ]
                        [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                            [ text "New Student" ]
                        ]
                    ]
                ]
            ]
        , viewForm model.form model.schools
        , viewBulkInput model.bulk
        , viewStudents model.students model.schools model.deleting model.filterSchool
        ]
    }


viewStudents : RemoteData (List Student) -> List School -> Maybe String -> String -> Html Msg
viewStudents students schools deleting filterSchool =
    case students of
        NotAsked ->
            text ""

        Loading ->
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

        Failed err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Succeeded list ->
            viewTable list schools deleting filterSchool


viewForm : FormState -> List School -> Html Msg
viewForm state schools =
    case state of
        FormHidden ->
            text ""

        FormOpen context formData errors ->
            viewFormBox context formData errors False schools

        FormSaving context formData ->
            viewFormBox context formData [] True schools


viewFormBox : FormContext -> StudentForm -> List String -> Bool -> List School -> Html Msg
viewFormBox context formData errors saving schools =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit Student"

                    Creating ->
                        "New Student"
                )
            ]
        , viewErrors errors
        , Html.form [ Events.onSubmit SaveStudent ]
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
                        [ label [ Attr.class "label" ] [ text "School" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormSchoolChanged ]
                                    (option [ Attr.value "" ] [ text "Select school..." ]
                                        :: List.map
                                            (\s ->
                                                option [ Attr.value s.id, Attr.selected (formData.school == s.id) ]
                                                    [ text s.name ]
                                            )
                                            schools
                                    )
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
            [ text "One student per line. Format: "
            , code [] [ text "Name, School Name" ]
            , text " (school name must match exactly)"
            ]
        , div [ Attr.class "field" ]
            [ div [ Attr.class "control" ]
                [ textarea
                    [ Attr.class "textarea"
                    , Attr.rows 6
                    , Attr.placeholder "Jane Doe, Lincoln High\nJohn Smith, Lincoln High\nAlex Johnson, Kennedy Middle"
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


viewTable : List Student -> List School -> Maybe String -> String -> Html Msg
viewTable students schools deleting filterSchool =
    let
        filtered =
            if filterSchool == "" then
                students

            else
                List.filter (\s -> s.school == filterSchool) students

        schoolName id =
            List.filter (\s -> s.id == id) schools
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault id
    in
    if List.isEmpty filtered then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No students yet." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Name" ]
                    , th [] [ text "School" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody [] (List.map (viewRow deleting schoolName) filtered)
            ]


viewRow : Maybe String -> (String -> String) -> Student -> Html Msg
viewRow deleting schoolName s =
    tr []
        [ td [] [ text s.name ]
        , td [] [ text (schoolName s.school) ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditStudent s) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if deleting == Just s.id then
                            "button is-danger is-outlined is-loading"

                         else
                            "button is-danger is-outlined"
                        )
                    , Events.onClick (DeleteStudent s.id)
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]
