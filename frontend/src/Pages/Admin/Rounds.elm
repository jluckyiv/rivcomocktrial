module Pages.Admin.Rounds exposing (Model, Msg, page)

import Api exposing (Round, Tournament)
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


init : () -> ( Model, Effect Msg )
init _ =
    ( { rounds = Loading
      , tournaments = []
      , form = FormHidden
      , deleting = Nothing
      , filterTournament = ""
      }
    , Effect.batch
        [ Pb.adminList { collection = "rounds", tag = "rounds", filter = "", sort = "" }
        , Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterTournamentChanged String
    | ShowCreateForm
    | EditRound Round
    | CancelForm
    | FormNumberChanged String
    | FormDateChanged String
    | FormTypeChanged String
    | FormTournamentChanged String
    | SaveRound
    | TogglePublished Round
    | DeleteRound String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "rounds" ->
                    case Pb.decodeList Api.roundDecoder value of
                        Ok items ->
                            ( { model | rounds = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | rounds = Failed "Failed to load rounds." }, Effect.none )

                Just "tournaments" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok items ->
                            ( { model | tournaments = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-round" ->
                    case Pb.decodeRecord Api.roundDecoder value of
                        Ok round ->
                            let
                                updateRound rounds =
                                    List.map
                                        (\r ->
                                            if r.id == round.id then
                                                round

                                            else
                                                r
                                        )
                                        rounds
                            in
                            case model.form of
                                FormSaving context _ ->
                                    let
                                        updateRounds =
                                            case context of
                                                Editing _ ->
                                                    updateRound

                                                Creating ->
                                                    \rounds -> rounds ++ [ round ]
                                    in
                                    ( { model
                                        | rounds = RemoteData.map updateRounds model.rounds
                                        , form = FormHidden
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    -- Toggle published (no form open)
                                    ( { model | rounds = RemoteData.map updateRound model.rounds }
                                    , Effect.none
                                    )

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save round." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-round" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | rounds = RemoteData.map (List.filter (\r -> r.id /= id)) model.rounds
                                , deleting = Nothing
                              }
                            , Effect.none
                            )

                        Err _ ->
                            ( { model | deleting = Nothing }, Effect.none )

                _ ->
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
                        , roundType = Api.roundTypeToString r.roundType
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
                                effect =
                                    case context of
                                        Editing id ->
                                            Pb.adminUpdate { collection = "rounds", id = id, tag = "save-round", body = Api.encodeRound data }

                                        Creating ->
                                            Pb.adminCreate { collection = "rounds", tag = "save-round", body = Api.encodeRound data }
                            in
                            ( { model | form = FormSaving context formData }, effect )

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
            ( model
            , Pb.adminUpdate { collection = "rounds", id = round.id, tag = "save-round", body = Api.encodeRound data }
            )

        DeleteRound id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "rounds", id = id, tag = "delete-round" }
            )



-- HELPERS


type alias ValidatedRound =
    { number : Int
    , date : String
    , roundType : Api.RoundType
    , published : Bool
    , tournament : String
    }


validateForm : RoundForm -> Result (List String) ValidatedRound
validateForm formData =
    let
        roundTypeResult =
            case formData.roundType of
                "preliminary" ->
                    Ok Api.Preliminary

                "elimination" ->
                    Ok Api.Elimination

                _ ->
                    Err "Round type must be preliminary or elimination"

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
                |> (case roundTypeResult of
                        Ok _ ->
                            identity

                        Err e ->
                            (::) e
                   )
    in
    if List.isEmpty errors then
        case ( String.toInt formData.number, roundTypeResult ) of
            ( Just n, Ok rt ) ->
                Ok
                    { number = n
                    , date = formData.date
                    , roundType = rt
                    , published = False
                    , tournament = formData.tournament
                    }

            _ ->
                Err errors

    else
        Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors


updateFormField : (RoundForm -> RoundForm) -> FormState -> FormState
updateFormField transform state =
    case state of
        FormOpen context formData _ ->
            FormOpen context (transform formData) []

        _ ->
            state


capitalize : String -> String
capitalize str =
    case String.uncons str of
        Just ( first, rest ) ->
            String.fromChar (Char.toUpper first) ++ rest

        Nothing ->
            str



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Pb.subscribe PbMsg



-- VIEW


view : Model -> View Msg
view model =
    { title = "Rounds"
    , body =
        [ UI.titleBar
            { title = "Rounds"
            , actions = [ { label = "New Round", msg = ShowCreateForm } ]
            }
        , UI.filterSelect
            { label = "Tournament:"
            , value = model.filterTournament
            , onInput = FilterTournamentChanged
            , options =
                { value = "", label = "All Tournaments" }
                    :: List.map (\t -> { value = t.id, label = t.name ++ " (" ++ String.fromInt t.year ++ ")" }) model.tournaments
            }
        , viewForm model.form model.tournaments
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.rounds of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded rounds ->
            let
                filtered =
                    if model.filterTournament == "" then
                        rounds

                    else
                        List.filter (\r -> r.tournament == model.filterTournament) rounds

                sorted =
                    List.sortBy .number filtered

                findTournamentName id =
                    List.filter (\t -> t.id == id) model.tournaments
                        |> List.head
                        |> Maybe.map .name
                        |> Maybe.withDefault id
            in
            if List.isEmpty sorted then
                UI.emptyState "No rounds yet."

            else
                UI.dataTable
                    { columns = [ "#", "Type", "Date", "Tournament", "Published", "Actions" ]
                    , rows = sorted
                    , rowView = viewRow model.deleting findTournamentName
                    }


viewForm : FormState -> List Tournament -> Html Msg
viewForm state tournaments =
    case state of
        FormHidden ->
            UI.empty

        FormOpen context formData errors ->
            viewFormCard context formData errors False tournaments

        FormSaving context formData ->
            viewFormCard context formData [] True tournaments


viewFormCard : FormContext -> RoundForm -> List String -> Bool -> List Tournament -> Html Msg
viewFormCard context formData errors saving tournaments =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Round"

                    Editing _ ->
                        "Edit Round"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveRound ]
                [ UI.formColumns
                    [ UI.selectField
                        { label = "Tournament"
                        , value = formData.tournament
                        , onInput = FormTournamentChanged
                        , options =
                            { value = "", label = "Select tournament..." }
                                :: List.map (\t -> { value = t.id, label = t.name ++ " (" ++ String.fromInt t.year ++ ")" }) tournaments
                        }
                    , UI.numberField
                        { label = "Round #"
                        , value = formData.number
                        , onInput = FormNumberChanged
                        , required = False
                        }
                    , UI.selectField
                        { label = "Type"
                        , value = formData.roundType
                        , onInput = FormTypeChanged
                        , options =
                            [ { value = "preliminary", label = "Preliminary" }
                            , { value = "elimination", label = "Elimination" }
                            ]
                        }
                    , UI.textField
                        { label = "Date"
                        , value = formData.date
                        , onInput = FormDateChanged
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


viewRow : Maybe String -> (String -> String) -> Round -> Html Msg
viewRow deleting findTournamentName r =
    tr []
        [ td [] [ text (String.fromInt r.number) ]
        , td [] [ text (capitalize (Api.roundTypeToString r.roundType)) ]
        , td [] [ text r.date ]
        , td [] [ text (findTournamentName r.tournament) ]
        , td []
            [ button
                [ Attr.class
                    (if r.published then
                        "btn btn-sm btn-success"

                     else
                        "btn btn-sm btn-ghost"
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
            [ div [ Attr.class "flex gap-2" ]
                [ a
                    [ Attr.class "btn btn-sm btn-outline"
                    , Attr.href ("/admin/pairings?round=" ++ r.id)
                    ]
                    [ text "Pairings" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-info"
                    , Events.onClick (EditRound r)
                    ]
                    [ text "Edit" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-error"
                    , Events.onClick (DeleteRound r.id)
                    , Attr.disabled (deleting == Just r.id)
                    ]
                    (if deleting == Just r.id then
                        [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                     else
                        [ text "Delete" ]
                    )
                ]
            ]
        ]
