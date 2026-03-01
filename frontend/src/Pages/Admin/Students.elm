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
    { students : List Student
    , schools : List School
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formName : String
    , formSchool : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    , filterSchool : String
    , bulkText : String
    , bulkSaving : Bool
    , bulkError : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { students = []
      , schools = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formName = ""
      , formSchool = ""
      , formSaving = False
      , editingId = Nothing
      , deleting = Nothing
      , filterSchool = ""
      , bulkText = ""
      , bulkSaving = False
      , bulkError = Nothing
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
            ( { model | students = response.items, loading = False }, Effect.none )

        GotStudents (Err _) ->
            ( { model | loading = False, error = Just "Failed to load students." }, Effect.none )

        GotSchools (Ok response) ->
            ( { model | schools = response.items }, Effect.none )

        GotSchools (Err _) ->
            ( model, Effect.none )

        FilterSchoolChanged val ->
            ( { model | filterSchool = val }, Effect.none )

        ShowCreateForm ->
            ( { model | showForm = True, editingId = Nothing, formName = "", formSchool = model.filterSchool }, Effect.none )

        EditStudent s ->
            ( { model | showForm = True, editingId = Just s.id, formName = s.name, formSchool = s.school }, Effect.none )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }, Effect.none )

        FormNameChanged val ->
            ( { model | formName = val }, Effect.none )

        FormSchoolChanged val ->
            ( { model | formSchool = val }, Effect.none )

        SaveStudent ->
            let
                data =
                    { name = model.formName, school = model.formSchool }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateStudent user.token id data GotSaveResponse

                        Nothing ->
                            Api.createStudent user.token data GotSaveResponse
            in
            ( { model | formSaving = True }, Effect.sendCmd cmd )

        GotSaveResponse (Ok student) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\s ->
                                    if s.id == student.id then
                                        student

                                    else
                                        s
                                )
                                model.students

                        Nothing ->
                            model.students ++ [ student ]
            in
            ( { model | students = updatedList, showForm = False, editingId = Nothing, formSaving = False }, Effect.none )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save student." }, Effect.none )

        DeleteStudent id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteStudent user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model | students = List.filter (\s -> s.id /= id) model.students, deleting = Nothing }, Effect.none )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete student." }, Effect.none )

        BulkTextChanged val ->
            ( { model | bulkText = val, bulkError = Nothing }, Effect.none )

        BulkImport ->
            let
                lines =
                    String.lines model.bulkText
                        |> List.map String.trim
                        |> List.filter (\l -> l /= "")

                parsed =
                    List.filterMap (parseBulkLine model.schools) lines

                errors =
                    List.length lines - List.length parsed
            in
            if List.isEmpty parsed then
                ( { model | bulkError = Just "No valid lines found. Format: Name, School Name" }, Effect.none )

            else if errors > 0 then
                ( { model | bulkError = Just (String.fromInt errors ++ " line(s) could not be parsed. Check school names match exactly.") }, Effect.none )

            else
                ( { model | bulkSaving = True, bulkError = Nothing }
                , Effect.batch
                    (List.map
                        (\data -> Effect.sendCmd (Api.createStudent user.token data GotBulkResponse))
                        parsed
                    )
                )

        GotBulkResponse (Ok student) ->
            ( { model
                | students = model.students ++ [ student ]
                , bulkSaving = False
                , bulkText = ""
              }
            , Effect.none
            )

        GotBulkResponse (Err _) ->
            ( { model | bulkSaving = False, bulkError = Just "Failed to create some students." }, Effect.none )



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
        , viewError model.error
        , if model.showForm then
            viewForm model

          else
            text ""
        , viewBulkInput model
        , if model.loading then
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

          else
            viewTable model
        ]
    }


viewBulkInput : Model -> Html Msg
viewBulkInput model =
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
                    , Attr.value model.bulkText
                    , Events.onInput BulkTextChanged
                    ]
                    []
                ]
            ]
        , case model.bulkError of
            Just err ->
                div [ Attr.class "notification is-danger is-light" ] [ text err ]

            Nothing ->
                text ""
        , div [ Attr.class "field" ]
            [ button
                [ Attr.class
                    (if model.bulkSaving then
                        "button is-info is-loading"

                     else
                        "button is-info"
                    )
                , Events.onClick BulkImport
                , Attr.disabled (String.trim model.bulkText == "")
                ]
                [ text "Import" ]
            ]
        ]


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
                        "Edit Student"

                    Nothing ->
                        "New Student"
                )
            ]
        , Html.form [ Events.onSubmit SaveStudent ]
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
                        [ label [ Attr.class "label" ] [ text "School" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormSchoolChanged ]
                                    (option [ Attr.value "" ] [ text "Select school..." ]
                                        :: List.map
                                            (\s ->
                                                option [ Attr.value s.id, Attr.selected (model.formSchool == s.id) ]
                                                    [ text s.name ]
                                            )
                                            model.schools
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
    let
        filtered =
            if model.filterSchool == "" then
                model.students

            else
                List.filter (\s -> s.school == model.filterSchool) model.students

        schoolName id =
            List.filter (\s -> s.id == id) model.schools
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
            , tbody []
                (List.map
                    (\s ->
                        tr []
                            [ td [] [ text s.name ]
                            , td [] [ text (schoolName s.school) ]
                            , td []
                                [ div [ Attr.class "buttons are-small" ]
                                    [ button [ Attr.class "button is-info is-outlined", Events.onClick (EditStudent s) ]
                                        [ text "Edit" ]
                                    , button
                                        [ Attr.class
                                            (if model.deleting == Just s.id then
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
                    )
                    filtered
                )
            ]
