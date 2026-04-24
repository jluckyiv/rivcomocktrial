module Pages.Admin.CaseCharacters exposing (Model, Msg, page)

import Api exposing (CaseCharacter, Tournament)
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


type alias CharacterForm =
    { tournament : String
    , side : String
    , characterName : String
    , description : String
    , sortOrder : String
    }


type FormState
    = FormHidden
    | FormOpen FormContext CharacterForm (List String)
    | FormSaving FormContext CharacterForm



-- MODEL


type alias Model =
    { characters : RemoteData (List CaseCharacter)
    , tournaments : List Tournament
    , form : FormState
    , deleting : Maybe String
    , filterTournament : String
    }


init : () -> ( Model, Effect Msg )
init _ =
    ( { characters = Loading
      , tournaments = []
      , form = FormHidden
      , deleting = Nothing
      , filterTournament = ""
      }
    , Effect.batch
        [ Pb.adminList { collection = "case_characters", tag = "case-characters", filter = "", sort = "sort_order" }
        , Pb.adminList { collection = "tournaments", tag = "tournaments", filter = "", sort = "" }
        ]
    )



-- UPDATE


type Msg
    = PbMsg Json.Decode.Value
    | FilterTournamentChanged String
    | ShowCreateForm
    | EditCharacter CaseCharacter
    | CancelForm
    | FormTournamentChanged String
    | FormSideChanged String
    | FormNameChanged String
    | FormDescriptionChanged String
    | FormSortOrderChanged String
    | SaveCharacter
    | DeleteCharacter String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        PbMsg value ->
            case Pb.responseTag value of
                Just "case-characters" ->
                    case Pb.decodeList Api.caseCharacterDecoder value of
                        Ok items ->
                            ( { model | characters = Succeeded items }, Effect.none )

                        Err _ ->
                            ( { model | characters = Failed "Failed to load case characters." }, Effect.none )

                Just "tournaments" ->
                    case Pb.decodeList Api.tournamentDecoder value of
                        Ok items ->
                            ( { model | tournaments = items }, Effect.none )

                        Err _ ->
                            ( model, Effect.none )

                Just "save-character" ->
                    case Pb.decodeRecord Api.caseCharacterDecoder value of
                        Ok character ->
                            let
                                updateCharacters context characters =
                                    case context of
                                        Editing _ ->
                                            List.map
                                                (\c ->
                                                    if c.id == character.id then
                                                        character

                                                    else
                                                        c
                                                )
                                                characters

                                        Creating ->
                                            characters ++ [ character ]
                            in
                            case model.form of
                                FormSaving context _ ->
                                    ( { model
                                        | characters = RemoteData.map (updateCharacters context) model.characters
                                        , form = FormHidden
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( model, Effect.none )

                        Err _ ->
                            case model.form of
                                FormSaving context formData ->
                                    ( { model | form = FormOpen context formData [ "Failed to save character." ] }, Effect.none )

                                _ ->
                                    ( model, Effect.none )

                Just "delete-character" ->
                    case Pb.decodeDelete value of
                        Ok id ->
                            ( { model
                                | characters = RemoteData.map (List.filter (\c -> c.id /= id)) model.characters
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
                        { tournament = model.filterTournament
                        , side = "prosecution"
                        , characterName = ""
                        , description = ""
                        , sortOrder = "0"
                        }
                        []
              }
            , Effect.none
            )

        EditCharacter c ->
            ( { model
                | form =
                    FormOpen (Editing c.id)
                        { tournament = c.tournament
                        , side = Api.rosterSideToString c.side
                        , characterName = c.characterName
                        , description = c.description
                        , sortOrder = String.fromInt c.sortOrder
                        }
                        []
              }
            , Effect.none
            )

        CancelForm ->
            ( { model | form = FormHidden }, Effect.none )

        FormTournamentChanged val ->
            ( { model | form = updateFormField (\f -> { f | tournament = val }) model.form }, Effect.none )

        FormSideChanged val ->
            ( { model | form = updateFormField (\f -> { f | side = val }) model.form }, Effect.none )

        FormNameChanged val ->
            ( { model | form = updateFormField (\f -> { f | characterName = val }) model.form }, Effect.none )

        FormDescriptionChanged val ->
            ( { model | form = updateFormField (\f -> { f | description = val }) model.form }, Effect.none )

        FormSortOrderChanged val ->
            ( { model | form = updateFormField (\f -> { f | sortOrder = val }) model.form }, Effect.none )

        SaveCharacter ->
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
                                                { collection = "case_characters"
                                                , id = id
                                                , tag = "save-character"
                                                , body = Api.encodeCaseCharacter data
                                                }

                                        Creating ->
                                            Pb.adminCreate
                                                { collection = "case_characters"
                                                , tag = "save-character"
                                                , body = Api.encodeCaseCharacter data
                                                }
                            in
                            ( { model | form = FormSaving context formData }, effect )

                _ ->
                    ( model, Effect.none )

        DeleteCharacter id ->
            ( { model | deleting = Just id }
            , Pb.adminDelete { collection = "case_characters", id = id, tag = "delete-character" }
            )



-- HELPERS


validateForm :
    CharacterForm
    -> Result (List String) { tournament : String, side : Api.RosterSide, characterName : String, description : String, sortOrder : Int }
validateForm formData =
    let
        parsedSide =
            case formData.side of
                "prosecution" ->
                    Just Api.Prosecution

                "defense" ->
                    Just Api.Defense

                _ ->
                    Nothing

        parsedOrder =
            String.toInt (String.trim formData.sortOrder)

        errors =
            []
                |> addErrorIf (String.trim formData.characterName == "") "Character name is required."
                |> addErrorIf (String.trim formData.tournament == "") "Tournament is required."
                |> addErrorIf (parsedSide == Nothing) "Side must be Prosecution or Defense."
                |> addErrorIf (parsedOrder == Nothing) "Sort order must be a number."
                |> addErrorIf (Maybe.map (\n -> n < 0) parsedOrder == Just True) "Sort order must be 0 or greater."
    in
    case ( List.isEmpty errors, parsedSide, parsedOrder ) of
        ( True, Just side, Just order ) ->
            Ok
                { tournament = formData.tournament
                , side = side
                , characterName = String.trim formData.characterName
                , description = String.trim formData.description
                , sortOrder = order
                }

        _ ->
            Err errors


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors


updateFormField : (CharacterForm -> CharacterForm) -> FormState -> FormState
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
    { title = "Case Characters"
    , body =
        [ UI.titleBar
            { title = "Case Characters"
            , actions =
                [ { label = "New Character", msg = ShowCreateForm }
                ]
            }
        , UI.filterSelect
            { label = "Tournament:"
            , value = model.filterTournament
            , onInput = FilterTournamentChanged
            , options =
                { value = "", label = "All Tournaments" }
                    :: List.map (\t -> { value = t.id, label = t.name }) model.tournaments
            }
        , viewForm model.form model.tournaments
        , viewDataTable model
        ]
    }


viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.characters of
        Loading ->
            UI.loading

        Failed err ->
            UI.error err

        Succeeded characters ->
            let
                filtered =
                    if model.filterTournament == "" then
                        characters

                    else
                        List.filter (\c -> c.tournament == model.filterTournament) characters

                sorted =
                    List.sortWith
                        (\a b ->
                            case compare (sideOrder a.side) (sideOrder b.side) of
                                EQ ->
                                    compare a.sortOrder b.sortOrder

                                other ->
                                    other
                        )
                        filtered
            in
            if List.isEmpty sorted then
                UI.emptyState "No case characters yet."

            else
                UI.dataTable
                    { columns = [ "Name", "Side", "Description", "Order", "Actions" ]
                    , rows = sorted
                    , rowView = viewRow model.deleting
                    }


sideOrder : Api.RosterSide -> Int
sideOrder side =
    case side of
        Api.Prosecution ->
            0

        Api.Defense ->
            1


sideLabel : Api.RosterSide -> String
sideLabel side =
    case side of
        Api.Prosecution ->
            "Prosecution"

        Api.Defense ->
            "Defense"


viewForm : FormState -> List Tournament -> Html Msg
viewForm state tournaments =
    case state of
        FormHidden ->
            UI.empty

        FormOpen context formData errors ->
            viewFormCard context formData errors False tournaments

        FormSaving context formData ->
            viewFormCard context formData [] True tournaments


viewFormCard : FormContext -> CharacterForm -> List String -> Bool -> List Tournament -> Html Msg
viewFormCard context formData errors saving tournaments =
    UI.card
        [ UI.cardBody
            [ UI.cardTitle
                (case context of
                    Creating ->
                        "New Character"

                    Editing _ ->
                        "Edit Character"
                )
            , UI.errorList errors
            , Html.form [ Events.onSubmit SaveCharacter ]
                [ UI.formColumns
                    [ UI.selectField
                        { label = "Tournament"
                        , value = formData.tournament
                        , onInput = FormTournamentChanged
                        , options =
                            { value = "", label = "Select tournament..." }
                                :: List.map (\t -> { value = t.id, label = t.name }) tournaments
                        }
                    , UI.selectField
                        { label = "Side"
                        , value = formData.side
                        , onInput = FormSideChanged
                        , options =
                            [ { value = "prosecution", label = "Prosecution" }
                            , { value = "defense", label = "Defense" }
                            ]
                        }
                    , UI.textField
                        { label = "Character Name"
                        , value = formData.characterName
                        , onInput = FormNameChanged
                        , required = True
                        }
                    , UI.textField
                        { label = "Description"
                        , value = formData.description
                        , onInput = FormDescriptionChanged
                        , required = False
                        }
                    , UI.textField
                        { label = "Sort Order"
                        , value = formData.sortOrder
                        , onInput = FormSortOrderChanged
                        , required = True
                        }
                    ]
                , div [ Attr.class "flex gap-2 mt-4" ]
                    [ UI.primaryButton { label = "Save", loading = saving }
                    , UI.cancelButton CancelForm
                    ]
                ]
            ]
        ]


viewRow : Maybe String -> CaseCharacter -> Html Msg
viewRow deleting c =
    tr []
        [ td [] [ text c.characterName ]
        , td [] [ UI.badge { label = sideLabel c.side, variant = sideVariant c.side } ]
        , td [] [ text c.description ]
        , td [] [ text (String.fromInt c.sortOrder) ]
        , td []
            [ div [ Attr.class "flex gap-2" ]
                [ button
                    [ Attr.class "btn btn-sm btn-outline btn-info"
                    , Events.onClick (EditCharacter c)
                    ]
                    [ text "Edit" ]
                , button
                    [ Attr.class "btn btn-sm btn-outline btn-error"
                    , Events.onClick (DeleteCharacter c.id)
                    , Attr.disabled (deleting == Just c.id)
                    ]
                    (if deleting == Just c.id then
                        [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

                     else
                        [ text "Delete" ]
                    )
                ]
            ]
        ]


sideVariant : Api.RosterSide -> String
sideVariant side =
    case side of
        Api.Prosecution ->
            "info"

        Api.Defense ->
            "warning"
