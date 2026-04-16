module Pages.Admin.Tournaments exposing (Model, Msg, page)

import Api exposing (Tournament)
import Auth
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
import Route.Path
import Shared
import Tournament
import UI
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


type alias TournamentForm =
    { name : String
    , year : String
    , prelimRounds : String
    , elimRounds : String
    , status : String
    }


type FormState
    = FormHidden
    | FormOpen FormContext TournamentForm (List String)
    | FormSaving FormContext TournamentForm



-- MODEL


type alias Model =
    { tournaments : RemoteData (List Tournament)
    , form : FormState
    , deleting : Maybe String
    }


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    ( { tournaments = Loading
      , form = FormHidden
      , deleting = Nothing
      }
    , Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | ShowCreateForm
    | EditTournament Tournament
    | CancelForm
    | FormNameChanged String
    | FormYearChanged String
    | FormPrelimRoundsChanged String
    | FormElimRoundsChanged String
    | FormStatusChanged String
    | SaveTournament
    | DeleteTournament String


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "tournaments" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok items ->
                            ( { model | tournaments = Succeeded items }, Effect.none )

                        Err err ->
                            ( { model | tournaments = Failed err }, Effect.none )

                Just "save-tournament" ->
                    case Pb.decodeRecord Api.tournamentDecoder value of
                        Ok tournament ->
                            let
                                updateTournaments context tournaments =
                                    case context of
                                        Editing _ ->
                                            List.map
                                                (\t ->
                                                    if t.id == tournament.id then
                                                        tournament

                                                    else
                                                        t
                                                )
                                                tournaments

                                        Creating ->
                                            tournaments ++ [ tournament ]
                            in
                            case model.form of
                                FormSaving context _ ->
                                    ( { model
                                        | tournaments = RemoteData.map (updateTournaments context) model.tournaments
                                        , form = FormHidden
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save tournament." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-tournament" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | tournaments = RemoteData.map (List.filter (\t -> t.id /= id)) model.tournaments
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ShowCreateForm ->
            ( { model
                | form =
                    FormOpen Creating
                        { name = ""
                        , year = ""
                        , prelimRounds = "4"
                        , elimRounds = "3"
                        , status = "draft"
                        }
                        []
              }
            , Effect.none
            )

        EditTournament t ->
            ( { model
                | form =
                    FormOpen (Editing t.id)
                        { name = t.name
                        , year = String.fromInt t.year
                        , prelimRounds = String.fromInt t.numPreliminaryRounds
                        , elimRounds = String.fromInt t.numEliminationRounds
                        , status = tournamentStatusToFormString t.status
                        }
                        []
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | name = val }) model.form }, Effect.none )

        FormYearChanged val ->
            ( { model | form = updateFormField (\f -> { f | year = val }) model.form }, Effect.none )

        FormPrelimRoundsChanged val ->
            ( { model | form = updateFormField (\f -> { f | prelimRounds = val }) model.form }, Effect.none )

        FormElimRoundsChanged val ->
            ( { model | form = updateFormField (\f -> { f | elimRounds = val }) model.form }, Effect.none )

        FormStatusChanged val ->
            ( { model | form = updateFormField (\f -> { f | status = val }) model.form }, Effect.none )

        SaveTournament ->
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
                                            Pb.adminUpdate { collection = "tournaments", id = id, tag = "save-tournament", body = Api.encodeTournament data }

                                        Creating ->
                                            Pb.adminCreate { collection = "tournaments", tag = "save-tournament", body = Api.encodeTournament data }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteTournament id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "tournaments", id = id, tag = "delete-tournament" }
            )



-- HELPERS


type alias ValidatedTournament =
    { name : String
    , year : Int
    , numPreliminaryRounds : Int
    , numEliminationRounds : Int
    , status : Api.TournamentStatus
    }


validateForm : TournamentForm -> Result (List String) ValidatedTournament
validateForm formData =
    let
        parseIntField label raw =
            case String.toInt raw of
                Just n ->
                    Ok n

                Nothing ->
                    Err [ label ++ " must be a number" ]

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

        toStrings =
            List.map (\(Error msg) -> msg)

        yearResult =
            parseIntField "Year" formData.year

        prelimResult =
            parseIntField "Preliminary rounds" formData.prelimRounds

        elimResult =
            parseIntField "Elimination rounds" formData.elimRounds

        nameValidation =
            Tournament.nameFromString formData.name |> Result.mapError toStrings

        yearValidation =
            yearResult |> Result.andThen (Tournament.yearFromInt >> Result.mapError toStrings)

        configValidation =
            Result.map2 (\p e -> ( p, e )) prelimResult elimResult
                |> Result.andThen (\( p, e ) -> Tournament.configFromInts p e |> Result.mapError toStrings)

        statusValidation =
            Tournament.statusFromString formData.status |> Result.mapError toStrings

        allErrors =
            collectErrors
                [ nameValidation |> Result.map (\_ -> ())
                , yearValidation |> Result.map (\_ -> ())
                , configValidation |> Result.map (\_ -> ())
                , statusValidation |> Result.map (\_ -> ())
                ]
    in
    if List.isEmpty allErrors then
        case ( yearResult, prelimResult, elimResult ) of
            ( Ok y, Ok p, Ok e ) ->
                case statusValidation of
                    Ok s ->
                        Ok
                            { name = String.trim formData.name
                            , year = y
                            , numPreliminaryRounds = p
                            , numEliminationRounds = e
                            , status = tournamentStatusFromDomain s
                            }

                    Err _ ->
                        Err allErrors

            _ ->
                Err allErrors

    else
        Err allErrors


tournamentStatusFromDomain : Tournament.Status -> Api.TournamentStatus
tournamentStatusFromDomain s =
    case String.toLower (Tournament.statusToString s) of
        "registration" ->
            Api.TournamentRegistration

        "active" ->
            Api.TournamentActive

        "completed" ->
            Api.TournamentCompleted

        _ ->
            Api.TournamentDraft


tournamentStatusToFormString : Api.TournamentStatus -> String
tournamentStatusToFormString s =
    case s of
        Api.TournamentDraft ->
            "draft"

        Api.TournamentRegistration ->
            "registration"

        Api.TournamentActive ->
            "active"

        Api.TournamentCompleted ->
            "completed"


updateFormField : (TournamentForm -> TournamentForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData _ ->
            FormOpen context (transform formData) []

        _ ->
            state



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Tournaments"
    , body =
        [ UI.titleBar
            { title = "Tournaments"
            , actions = [ { label = "New Tournament", msg = ShowCreateForm } ]
            }
        , viewForm model.form
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.tournaments of
        NotAsked ->
            UI.empty

        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded [] ->
            UI.emptyState "No tournaments yet. Create one to get started."

        Succeeded tournaments ->
            UI.dataTable
                { columns = [ "Name", "Year", "Rounds", "Status", "Actions" ]
                , rows = tournaments
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


viewFormCard : FormContext -> TournamentForm -> List String -> Bool -> Html Msg
viewFormCard context formData errors saving =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Tournament"

                    Editing _ ->
                        "Edit Tournament"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveTournament ]
                [ UI.formColumns
                    [ UI.textField
                        { label = "Name"
                        , value = formData.name
                        , onInput = FormNameChanged
                        , required = True
                        }
                    , UI.numberField
                        { label = "Year"
                        , value = formData.year
                        , onInput = FormYearChanged
                        , required = True
                        }
                    ]
                , UI.formColumns
                    [ UI.numberField
                        { label = "Preliminary Rounds"
                        , value = formData.prelimRounds
                        , onInput = FormPrelimRoundsChanged
                        , required = False
                        }
                    , UI.numberField
                        { label = "Elimination Rounds"
                        , value = formData.elimRounds
                        , onInput = FormElimRoundsChanged
                        , required = False
                        }
                    , UI.selectField
                        { label = "Status"
                        , value = formData.status
                        , onInput = FormStatusChanged
                        , options =
                            [ { value = "draft", label = "Draft" }
                            , { value = "registration", label = "Registration" }
                            , { value = "active", label = "Active" }
                            , { value = "completed", label = "Completed" }
                            ]
                        }
                    ]
                , div [ Attr.class "flex gap-2 mt-4" ]
                    [ UI.primaryButton { label = "Save", loading = saving }
                    , UI.cancelButton CancelForm
                    ]
                ]
            ]
        ]


viewRow : Maybe String -> Tournament -> Html Msg
viewRow deleting t =
    tr []
        [ td [] [ text t.name ]
        , td [] [ text (String.fromInt t.year) ]
        , td [] [ text (String.fromInt t.numPreliminaryRounds ++ "P + " ++ String.fromInt t.numEliminationRounds ++ "E") ]
        , td [] [ viewStatusBadge t.status ]
        , td []
            [ div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-outline btn-info"
                    , Events.onClick (EditTournament t)
                    ]
                    [ text "Edit" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-error"
                    , Events.onClick (DeleteTournament t.id)
                    , Attr.disabled (deleting == Just t.id)
                    ]
                    (if deleting == Just t.id then
                        [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                     else
                        [ text "Delete" ]
                    )
                ]
            ]
        ]


viewStatusBadge : Api.TournamentStatus -> Html msg
viewStatusBadge status =
    case status of
        Api.TournamentDraft ->
            UI.badge { label = "Draft", variant = "ghost" }

        Api.TournamentRegistration ->
            UI.badge { label = "Registration", variant = "info" }

        Api.TournamentActive ->
            UI.badge { label = "Active", variant = "success" }

        Api.TournamentCompleted ->
            UI.badge { label = "Completed", variant = "neutral" }
