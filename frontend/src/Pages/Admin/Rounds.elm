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



-- MODEL


type alias Model =
    { rounds : List Round
    , tournaments : List Tournament
    , loading : Bool
    , error : Maybe String
    , showForm : Bool
    , formNumber : String
    , formDate : String
    , formType : String
    , formTournament : String
    , formSaving : Bool
    , editingId : Maybe String
    , deleting : Maybe String
    , filterTournament : String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { rounds = []
      , tournaments = []
      , loading = True
      , error = Nothing
      , showForm = False
      , formNumber = ""
      , formDate = ""
      , formType = "preliminary"
      , formTournament = ""
      , formSaving = False
      , editingId = Nothing
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
            ( { model | rounds = response.items, loading = False }, Effect.none )

        GotRounds (Err _) ->
            ( { model | loading = False, error = Just "Failed to load rounds." }, Effect.none )

        GotTournaments (Ok response) ->
            ( { model | tournaments = response.items }, Effect.none )

        GotTournaments (Err _) ->
            ( model, Effect.none )

        FilterTournamentChanged val ->
            ( { model | filterTournament = val }, Effect.none )

        ShowCreateForm ->
            ( { model
                | showForm = True
                , editingId = Nothing
                , formNumber = ""
                , formDate = ""
                , formType = "preliminary"
                , formTournament = model.filterTournament
              }
            , Effect.none
            )

        EditRound r ->
            ( { model
                | showForm = True
                , editingId = Just r.id
                , formNumber = String.fromInt r.number
                , formDate = r.date
                , formType = r.roundType
                , formTournament = r.tournament
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | showForm = False, editingId = Nothing }, Effect.none )

        FormNumberChanged val ->
            ( { model | formNumber = val }, Effect.none )

        FormDateChanged val ->
            ( { model | formDate = val }, Effect.none )

        FormTypeChanged val ->
            ( { model | formType = val }, Effect.none )

        FormTournamentChanged val ->
            ( { model | formTournament = val }, Effect.none )

        SaveRound ->
            let
                data =
                    { number = String.toInt model.formNumber |> Maybe.withDefault 0
                    , date = model.formDate
                    , roundType = model.formType
                    , published = False
                    , tournament = model.formTournament
                    }

                cmd =
                    case model.editingId of
                        Just id ->
                            Api.updateRound user.token id data GotSaveResponse

                        Nothing ->
                            Api.createRound user.token data GotSaveResponse
            in
            ( { model | formSaving = True }, Effect.sendCmd cmd )

        GotSaveResponse (Ok round) ->
            let
                updatedList =
                    case model.editingId of
                        Just _ ->
                            List.map
                                (\r ->
                                    if r.id == round.id then
                                        round

                                    else
                                        r
                                )
                                model.rounds

                        Nothing ->
                            model.rounds ++ [ round ]
            in
            ( { model | rounds = updatedList, showForm = False, editingId = Nothing, formSaving = False }, Effect.none )

        GotSaveResponse (Err _) ->
            ( { model | formSaving = False, error = Just "Failed to save round." }, Effect.none )

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
                    List.map
                        (\r ->
                            if r.id == round.id then
                                round

                            else
                                r
                        )
                        model.rounds
              }
            , Effect.none
            )

        GotToggleResponse (Err _) ->
            ( { model | error = Just "Failed to update published status." }, Effect.none )

        DeleteRound id ->
            ( { model | deleting = Just id }
            , Effect.sendCmd (Api.deleteRound user.token id (GotDeleteResponse id))
            )

        GotDeleteResponse id (Ok _) ->
            ( { model | rounds = List.filter (\r -> r.id /= id) model.rounds, deleting = Nothing }, Effect.none )

        GotDeleteResponse _ (Err _) ->
            ( { model | deleting = Nothing, error = Just "Failed to delete round." }, Effect.none )



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
                        "Edit Round"

                    Nothing ->
                        "New Round"
                )
            ]
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
                                                option [ Attr.value t.id, Attr.selected (model.formTournament == t.id) ]
                                                    [ text (t.name ++ " (" ++ String.fromInt t.year ++ ")") ]
                                            )
                                            model.tournaments
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
                                , Attr.value model.formNumber
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
                                    [ option [ Attr.value "preliminary", Attr.selected (model.formType == "preliminary") ] [ text "Preliminary" ]
                                    , option [ Attr.value "elimination", Attr.selected (model.formType == "elimination") ] [ text "Elimination" ]
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
                                , Attr.value model.formDate
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
            if model.filterTournament == "" then
                model.rounds

            else
                List.filter (\r -> r.tournament == model.filterTournament) model.rounds

        sorted =
            List.sortBy .number filtered

        findTournamentName id =
            List.filter (\t -> t.id == id) model.tournaments
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
            , tbody []
                (List.map
                    (\r ->
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
                                            (if model.deleting == Just r.id then
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
                    )
                    sorted
                )
            ]


capitalize : String -> String
capitalize str =
    case String.uncons str of
        Just ( first, rest ) ->
            String.fromChar (Char.toUpper first) ++ rest

        Nothing ->
            str
