module Pages.Admin.Rounds exposing (Model, Msg, page)

import Api exposing (Round, Tournament)
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


type alias RoundForm =
    { number : String
    , date : String
    , roundType : String
    , tournament : String
    }


type FormState
    = FormHidden
    | FormOpen FormContext RoundForm (List String)
    | FormSaving FormContext RoundForm



-- MODEL


type alias Model =
    { rounds : RemoteData (List Round)
    , tournaments : List Tournament
    , form : FormState
    , deleting : Maybe String
    , filterTournament : String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { rounds = Loading
      , tournaments = []
      , form = FormHidden
      , deleting = Nothing
      , filterTournament = ""
      }
    , Effect.batch
        [ Effect.sendCmd (Api.listRounds user.token GotRounds)
        , Effect.sendCmd (Api.listTournaments user.token GotTournaments)
        ]
    )



-- UPDATE


type Msg
    = GotRounds (Result Http.Error (Api.ListResponse Round))
    | GotTournaments (Result Http.Error (Api.ListResponse Tournament))
    | FilterTournamentChanged String
    | ShowCreateForm
    | EditRound Round
    | CancelForm
    | FormNumberChanged String
    | FormDateChanged String
    | FormTypeChanged String
    | FormTournamentChanged String
    | SaveRound
    | GotSaveResponse (Result Http.Error Round)
    | TogglePublished Round
    | GotToggleResponse (Result Http.Error Round)
    | DeleteRound String
    | GotDeleteResponse String (Result Http.Error ())


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        GotRounds (Ok response) ->
            ( { model | rounds = Succeeded response.items }, Effect.none )

        GotRounds (Err _) ->
            ( { model | rounds = Failed "Failed to load rounds." }, Effect.none )

        GotTournaments (Ok response) ->
            ( { model | tournaments = response.items }, Effect.none )

        GotTournaments (Err _) ->
            ( model, Effect.none )

        FilterTournamentChanged val ->
            ( { model | filterTournament = val }, Effect.none )

        ShowCreateForm ->
            ( { model
                | form =
                    FormOpen Creating
                        { number = ""
                        , date = ""
                        , roundType = "preliminary"
                        , tournament = model.filterTournament
                        }
                        []
              }
            , Effect.none
            )

        EditRound r ->
            ( { model
                | form =
                    FormOpen (Editing r.id)
                        { number = String.fromInt r.number
                        , date = r.date
                        , roundType = r.roundType
                        , tournament = r.tournament
                        }
                        []
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNumberChanged val ->
            ( { model | form = updateFormField (\f -> { f | number = val }) model.form }, Effect.none )

        FormDateChanged val ->
            ( { model | form = updateFormField (\f -> { f | date = val }) model.form }, Effect.none )

        FormTypeChanged val ->
            ( { model | form = updateFormField (\f -> { f | roundType = val }) model.form }, Effect.none )

        FormTournamentChanged val ->
            ( { model | form = updateFormField (\f -> { f | tournament = val }) model.form }, Effect.none )

        SaveRound ->
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
                                            Api.updateRound user.token id data GotSaveResponse

                                        Creating ->
                                            Api.createRound user.token data GotSaveResponse
                            in
                            ( { model | form = FormSaving context formData }, Effect.sendCmd cmd )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Ok round) ->
            let
                updateRounds context rounds =
                    case context of
                        Editing _ ->
                            List.map
                                (\r ->
                                    if r.id == round.id then
                                        round

                                    else
                                        r
                                )
                                rounds

                        Creating ->
                            rounds ++ [ round ]
            in
            case model.form of
                FormSaving context _ ->
                    ( { model
                        | rounds = RemoteData.map (updateRounds context) model.rounds
                        , form = FormHidden
                      }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        GotSaveResponse (Err _) ->
            case model.form of
                FormSaving context formData ->
                    ( { model | form = FormOpen context formData [ "Failed to save round." ] }, Effect.none )

                _ ->
                    ( model, Effect.none )

        TogglePublished round ->
            let
                data =
                    { number = round.number
                    , date = round.date
                    , roundType = round.roundType
                    , published = not round.published
                    , tournament = round.tournament
                    }
            in
            ( model, Effect.sendCmd (Api.updateRound user.token round.id data GotToggleResponse) )

        GotToggleResponse (Ok round) ->
            ( { model
                | rounds =
                    RemoteData.map
                        (List.map
                            (\r ->
                                if r.id == round.id then
                                    round

                                else
                                    r
                            )
                        )
                        model.rounds
              }
            , Effect.none
            )

        GotToggleResponse (Err _) ->
            ( model, Effect.none )

        DeleteRound id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteRound user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model
                | rounds = RemoteData.map (List.filter (\r -> r.id /= id)) model.rounds
                , deleting = Nothing
              }
            , Effect.none
            )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing }, Effect.none )



-- HELPERS


type alias ValidatedRound =
    { number : Int
    , date : String
    , roundType : String
    , published : Bool
    , tournament : String
    }


validateForm : RoundForm -> Result (List String) ValidatedRound
validateForm formData =
    let
        errors =
            []
                |> addErrorIf (String.trim formData.tournament == "") "Tournament is required"
                |> addErrorIf
                    (case String.toInt formData.number of
                        Just n ->
                            n < 1

                        Nothing ->
                            True
                    )
                    "Round number must be a positive integer"
                |> addErrorIf (String.trim formData.date == "") "Date is required"
                |> addErrorIf (not (List.member formData.roundType [ "preliminary", "elimination" ])) "Round type must be preliminary or elimination"
    in
    if List.isEmpty errors then
        case String.toInt formData.number of
            Just n ->
                Ok
                    { number = n
                    , date = formData.date
                    , roundType = formData.roundType
                    , published = False
                    , tournament = formData.tournament
                    }

            Nothing ->
                Err errors

    else
        Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition error errors =
    if condition then
        errors ++ [ error ]

    else
        errors


updateFormField : (RoundForm -> RoundForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData _ ->
            FormOpen context (transform formData) []

        _ ->
            state



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Rounds"
    , body =
        [ div [ Attr.class "level" ]
            [ div [ Attr.class "level-left" ]
                [ h1 [ Attr.class "title" ] [ text "Rounds" ] ]
            , div [ Attr.class "level-right" ]
                [ div [ Attr.class "field has-addons" ]
                    [ div [ Attr.class "control" ]
                        [ div [ Attr.class "select" ]
                            [ select [ Events.onInput FilterTournamentChanged ]
                                (option [ Attr.value "" ] [ text "All Tournaments" ]
                                    :: List.map
                                        (\t ->
                                            option [ Attr.value t.id, Attr.selected (model.filterTournament == t.id) ]
                                                [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                        )
                                        model.tournaments
                                )
                            ]
                        ]
                    , div [ Attr.class "control" ]
                        [ button [ Attr.class "button is-primary", Events.onClick ShowCreateForm ]
                            [ text "New Round" ]
                        ]
                    ]
                ]
            ]
        , viewForm model.form model.tournaments
        , viewRounds model.rounds model.tournaments model.deleting model.filterTournament
        ]
    }


viewRounds : RemoteData (List Round) -> List Tournament -> Maybe String -> String -> Html Msg
viewRounds rounds tournaments deleting filterTournament =
    case rounds of
        NotAsked ->
            text ""

        Loading ->
            div [ Attr.class "has-text-centered" ] [ text "Loading..." ]

        Failed err ->
            div [ Attr.class "notification is-danger" ] [ text err ]

        Succeeded list ->
            viewTable list tournaments deleting filterTournament


viewForm : FormState -> List Tournament -> Html Msg
viewForm state tournaments =
    case state of
        FormHidden ->
            text ""

        FormOpen context formData errors ->
            viewFormBox context formData errors False tournaments

        FormSaving context formData ->
            viewFormBox context formData [] True tournaments


viewFormBox : FormContext -> RoundForm -> List String -> Bool -> List Tournament -> Html Msg
viewFormBox context formData errors saving tournaments =
    div [ Attr.class "box mb-5" ]
        [ h2 [ Attr.class "subtitle" ]
            [ text
                (case context of
                    Editing _ ->
                        "Edit Round"

                    Creating ->
                        "New Round"
                )
            ]
        , viewErrors errors
        , Html.form [ Events.onSubmit SaveRound ]
            [ div [ Attr.class "columns" ]
                [ div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Tournament" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormTournamentChanged ]
                                    (option [ Attr.value "" ] [ text "Select tournament..." ]
                                        :: List.map
                                            (\t ->
                                                option [ Attr.value t.id, Attr.selected (formData.tournament == t.id) ]
                                                    [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                            )
                                            tournaments
                                    )
                                ]
                            ]
                        ]
                    ]
                , div [ Attr.class "column is-2" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Round #" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.type_ "number"
                                , Attr.value formData.number
                                , Events.onInput FormNumberChanged
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Type" ]
                        , div [ Attr.class "control" ]
                            [ div [ Attr.class "select is-fullwidth" ]
                                [ select [ Events.onInput FormTypeChanged ]
                                    [ option [ Attr.value "preliminary", Attr.selected (formData.roundType == "preliminary") ] [ text "Preliminary" ]
                                    , option [ Attr.value "elimination", Attr.selected (formData.roundType == "elimination") ] [ text "Elimination" ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                , div [ Attr.class "column" ]
                    [ div [ Attr.class "field" ]
                        [ label [ Attr.class "label" ] [ text "Date" ]
                        , div [ Attr.class "control" ]
                            [ input
                                [ Attr.class "input"
                                , Attr.value formData.date
                                , Attr.placeholder "e.g. Feb 15, 2025"
                                , Events.onInput FormDateChanged
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


viewErrors : List String -> Html msg
viewErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "notification is-danger is-light" ]
            [ ul [] (List.map (\e -> li [] [ text e ]) errors) ]


viewTable : List Round -> List Tournament -> Maybe String -> String -> Html Msg
viewTable rounds tournaments deleting filterTournament =
    let
        filtered =
            if filterTournament == "" then
                rounds

            else
                List.filter (\r -> r.tournament == filterTournament) rounds

        sorted =
            List.sortBy .number filtered

        findTournamentName id =
            List.filter (\t -> t.id == id) tournaments
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault id
    in
    if List.isEmpty sorted then
        div [ Attr.class "has-text-centered has-text-grey" ]
            [ p [] [ text "No rounds yet." ] ]

    else
        table [ Attr.class "table is-fullwidth is-striped" ]
            [ thead []
                [ tr []
                    [ th [] [ text "#" ]
                    , th [] [ text "Type" ]
                    , th [] [ text "Date" ]
                    , th [] [ text "Tournament" ]
                    , th [] [ text "Published" ]
                    , th [] [ text "Actions" ]
                    ]
                ]
            , tbody [] (List.map (viewRow deleting findTournamentName) sorted)
            ]


viewRow : Maybe String -> (String -> String) -> Round -> Html Msg
viewRow deleting findTournamentName r =
    tr []
        [ td [] [ text (String.fromInt r.number) ]
        , td [] [ text (capitalize r.roundType) ]
        , td [] [ text r.date ]
        , td [] [ text (findTournamentName r.tournament) ]
        , td []
            [ button
                [ Attr.class
                    (if r.published then
                        "button is-small is-success"

                     else
                        "button is-small is-light"
                    )
                , Events.onClick (TogglePublished r)
                ]
                [ text
                    (if r.published then
                        "Published"

                     else
                        "Draft"
                    )
                ]
            ]
        , td []
            [ div [ Attr.class "buttons are-small" ]
                [ a
                    [ Attr.class "button is-link is-outlined"
                    , Attr.href ("/admin/pairings?round=" ++ r.id)
                    ]
                    [ text "Pairings" ]
                , button [ Attr.class "button is-info is-outlined", Events.onClick (EditRound r) ]
                    [ text "Edit" ]
                , button
                    [ Attr.class
                        (if deleting == Just r.id then
                            "button is-danger is-outlined is-loading"

                         else
                            "button is-danger is-outlined"
                        )
                    , Events.onClick (DeleteRound r.id)
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]


capitalize : String -> String
capitalize str =
    case String.uncons str of
        Just ( first, rest ) ->
            String.fromChar (Char.toUpper first) ++ rest

        Nothing ->
            str
