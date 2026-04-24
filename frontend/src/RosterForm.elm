module RosterForm exposing
    ( FormData
    , FormRow
    , FormState(..)
    , FormViewConfig
    , emptyRow
    , entryToFormRow
    , parseEntryType
    , parseRole
    , roleName
    , sideLabel
    , updateFormRows
    , updateRow
    , validateForm
    , viewFormContent
    )

{-| Shared form logic for the coach and admin roster pages.

Covers types, conversion functions, validation, row-update helpers,
and the shared form view. The save/submit handlers stay in each page
because they use different PocketBase privilege levels.

-}

import Api
import Html exposing (Html, button, div, option, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes as Attr
import Html.Events as Events
import UI



-- TYPES


type FormState
    = FormHidden
    | FormEditing FormData (List String)
    | FormSaving FormData


{-| Form data for a roster edit session.

`teamId` is always present — the coach page sets it from the team
record; the admin page carries it from the selected cell.

-}
type alias FormData =
    { teamId : String
    , roundId : String
    , side : Api.RosterSide
    , rows : List FormRow
    , submitting : Bool
    }


type alias FormRow =
    { id : Maybe String
    , student : String
    , entryType : String
    , role : String
    , character : String
    }


emptyRow : FormRow
emptyRow =
    { id = Nothing
    , student = ""
    , entryType = "active"
    , role = ""
    , character = ""
    }



-- CONVERSION


entryToFormRow : Api.RosterEntry -> FormRow
entryToFormRow entry =
    { id = Just entry.id
    , student = Maybe.withDefault "" entry.student
    , entryType = entryTypeToString entry.entryType
    , role = roleToString entry.role
    , character = Maybe.withDefault "" entry.character
    }


entryTypeToString : Api.EntryType -> String
entryTypeToString et =
    case et of
        Api.ActiveEntry ->
            "active"

        Api.SubstituteEntry ->
            "substitute"

        Api.NonActiveEntry ->
            "non_active"


roleToString : Maybe Api.RosterRole -> String
roleToString maybeRole =
    case maybeRole of
        Nothing ->
            ""

        Just Api.PretrialAttorneyRole ->
            "pretrial_attorney"

        Just Api.TrialAttorneyRole ->
            "trial_attorney"

        Just Api.WitnessRole ->
            "witness"

        Just Api.ClerkRole ->
            "clerk"

        Just Api.BailiffRole ->
            "bailiff"

        Just Api.ArtistRole ->
            "artist"

        Just Api.JournalistRole ->
            "journalist"


roleName : Maybe Api.RosterRole -> String
roleName maybeRole =
    case maybeRole of
        Nothing ->
            "—"

        Just Api.PretrialAttorneyRole ->
            "Pretrial Attorney"

        Just Api.TrialAttorneyRole ->
            "Trial Attorney"

        Just Api.WitnessRole ->
            "Witness"

        Just Api.ClerkRole ->
            "Clerk"

        Just Api.BailiffRole ->
            "Bailiff"

        Just Api.ArtistRole ->
            "Courtroom Artist"

        Just Api.JournalistRole ->
            "Courtroom Journalist"


parseEntryType : String -> Api.EntryType
parseEntryType s =
    case s of
        "substitute" ->
            Api.SubstituteEntry

        "non_active" ->
            Api.NonActiveEntry

        _ ->
            Api.ActiveEntry


parseRole : String -> Maybe Api.RosterRole
parseRole s =
    case s of
        "pretrial_attorney" ->
            Just Api.PretrialAttorneyRole

        "trial_attorney" ->
            Just Api.TrialAttorneyRole

        "witness" ->
            Just Api.WitnessRole

        "clerk" ->
            Just Api.ClerkRole

        "bailiff" ->
            Just Api.BailiffRole

        "artist" ->
            Just Api.ArtistRole

        "journalist" ->
            Just Api.JournalistRole

        _ ->
            Nothing


sideLabel : Api.RosterSide -> String
sideLabel side =
    case side of
        Api.Prosecution ->
            "Prosecution"

        Api.Defense ->
            "Defense"


roleOptionsForSide : Api.RosterSide -> List { value : String, label : String }
roleOptionsForSide side =
    let
        common =
            [ { value = "", label = "Select role..." }
            , { value = "pretrial_attorney", label = "Pretrial Attorney" }
            , { value = "trial_attorney", label = "Trial Attorney" }
            , { value = "witness", label = "Witness" }
            , { value = "artist", label = "Courtroom Artist" }
            , { value = "journalist", label = "Courtroom Journalist" }
            ]

        sideSpecific =
            case side of
                Api.Prosecution ->
                    [ { value = "clerk", label = "Clerk" } ]

                Api.Defense ->
                    [ { value = "bailiff", label = "Bailiff" } ]
    in
    common ++ sideSpecific



-- VALIDATION


validateForm : FormData -> Result (List String) (List FormRow)
validateForm formData =
    let
        nonEmptyRows =
            List.filter (\r -> r.student /= "" || r.role /= "") formData.rows

        errors =
            nonEmptyRows
                |> List.indexedMap
                    (\i r ->
                        []
                            |> addErrorIf (r.student == "" && r.entryType /= "non_active")
                                ("Row " ++ String.fromInt (i + 1) ++ ": student is required.")
                            |> addErrorIf (r.entryType == "active" && r.role == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": role is required for active members.")
                            |> addErrorIf (r.role == "witness" && r.character == "")
                                ("Row " ++ String.fromInt (i + 1) ++ ": character is required for witnesses.")
                    )
                |> List.concat

        duplicateStudents =
            let
                studentIds =
                    List.filterMap
                        (\r ->
                            if r.student /= "" then
                                Just r.student

                            else
                                Nothing
                        )
                        nonEmptyRows

                hasDuplicates ids =
                    List.length ids /= List.length (unique ids)
            in
            if hasDuplicates studentIds then
                [ "Each student can only appear once per roster." ]

            else
                []
    in
    if List.isEmpty nonEmptyRows then
        Err [ "Add at least one roster entry." ]

    else if List.isEmpty errors && List.isEmpty duplicateStudents then
        Ok nonEmptyRows

    else
        Err (errors ++ duplicateStudents)


unique : List comparable -> List comparable
unique list =
    List.foldl
        (\item acc ->
            if List.member item acc then
                acc

            else
                acc ++ [ item ]
        )
        []
        list


addErrorIf : Bool -> String -> List String -> List String
addErrorIf condition err errors =
    if condition then
        errors ++ [ err ]

    else
        errors



-- STATE HELPERS


updateFormRows : (List FormRow -> List FormRow) -> FormState -> FormState
updateFormRows transform state =
    case state of
        FormEditing formData _ ->
            FormEditing { formData | rows = transform formData.rows } []

        _ ->
            state


updateRow : Int -> (FormRow -> FormRow) -> FormState -> FormState
updateRow idx transform state =
    updateFormRows
        (List.indexedMap
            (\i r ->
                if i == idx then
                    transform r

                else
                    r
            )
        )
        state



-- VIEW


{-| Config record for the shared form view.

Pass page-specific message constructors so the view stays
decoupled from any particular page's Msg type.

-}
type alias FormViewConfig msg =
    { students : List Api.Student
    , caseCharacters : List Api.CaseCharacter
    , onAddRow : msg
    , onRemoveRow : Int -> msg
    , onUpdateStudent : Int -> String -> msg
    , onUpdateEntryType : Int -> String -> msg
    , onUpdateRole : Int -> String -> msg
    , onUpdateCharacter : Int -> String -> msg
    , onSaveDraft : msg
    , onSubmitRoster : msg
    , onCancel : msg
    }


{-| Render the roster editing form.

The caller pattern-matches on FormState and passes FormData,
errors, and saving flag. This function handles the table of
rows plus the action buttons.

-}
viewFormContent :
    FormViewConfig msg
    -> FormData
    -> List String
    -> Bool
    -> Html msg
viewFormContent config formData errors saving =
    let
        sideCharacters =
            config.caseCharacters
                |> List.filter (\c -> c.side == formData.side)

        assignedStudents =
            List.map .student formData.rows
                |> List.filter (\s -> s /= "")
    in
    div [ Attr.class "py-2" ]
        [ UI.errorList errors
        , table [ Attr.class "table table-sm w-full" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Student" ]
                    , th [] [ text "Type" ]
                    , th [] [ text "Role" ]
                    , th [] [ text "Character" ]
                    , th [] []
                    ]
                ]
            , tbody []
                (List.indexedMap
                    (viewFormRow config sideCharacters assignedStudents formData.side)
                    formData.rows
                )
            ]
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick config.onAddRow
                , Attr.disabled saving
                ]
                [ text "+ Add Row" ]
            ]
        , div [ Attr.class "flex gap-2 mt-4" ]
            [ button
                [ Attr.class "btn btn-primary btn-sm"
                , Events.onClick config.onSaveDraft
                , Attr.disabled saving
                ]
                (if saving && not formData.submitting then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Saving..."
                    ]

                 else
                    [ text "Save Draft" ]
                )
            , button
                [ Attr.class "btn btn-success btn-sm"
                , Events.onClick config.onSubmitRoster
                , Attr.disabled saving
                ]
                (if saving && formData.submitting then
                    [ span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , text "Submitting..."
                    ]

                 else
                    [ text "Submit Roster" ]
                )
            , button
                [ Attr.class "btn btn-ghost btn-sm"
                , Events.onClick config.onCancel
                , Attr.disabled saving
                ]
                [ text "Cancel" ]
            ]
        ]


viewFormRow :
    FormViewConfig msg
    -> List Api.CaseCharacter
    -> List String
    -> Api.RosterSide
    -> Int
    -> FormRow
    -> Html msg
viewFormRow config sideCharacters assignedStudents side idx row =
    let
        availableStudents =
            config.students
                |> List.filter
                    (\s ->
                        s.id == row.student || not (List.member s.id assignedStudents)
                    )
    in
    tr []
        [ td []
            [ select
                [ Attr.class "select select-sm select-bordered w-full"
                , Events.onInput (config.onUpdateStudent idx)
                , Attr.value row.student
                ]
                ({ value = "", label = "Select student..." }
                    :: List.map (\s -> { value = s.id, label = s.name }) availableStudents
                    |> List.map (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.student) ] [ text o.label ])
                )
            ]
        , td []
            [ select
                [ Attr.class "select select-sm select-bordered"
                , Events.onInput (config.onUpdateEntryType idx)
                , Attr.value row.entryType
                ]
                [ option [ Attr.value "active", Attr.selected (row.entryType == "active") ] [ text "Active" ]
                , option [ Attr.value "substitute", Attr.selected (row.entryType == "substitute") ] [ text "Substitute" ]
                , option [ Attr.value "non_active", Attr.selected (row.entryType == "non_active") ] [ text "Non-Active" ]
                ]
            ]
        , td []
            [ if row.entryType == "non_active" then
                text "—"

              else
                select
                    [ Attr.class "select select-sm select-bordered"
                    , Events.onInput (config.onUpdateRole idx)
                    , Attr.value row.role
                    ]
                    (List.map
                        (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.role) ] [ text o.label ])
                        (roleOptionsForSide side)
                    )
            ]
        , td []
            [ if row.role == "witness" then
                select
                    [ Attr.class "select select-sm select-bordered"
                    , Events.onInput (config.onUpdateCharacter idx)
                    , Attr.value row.character
                    ]
                    ({ value = "", label = "Select character..." }
                        :: List.map (\c -> { value = c.id, label = c.characterName }) sideCharacters
                        |> List.map (\o -> option [ Attr.value o.value, Attr.selected (o.value == row.character) ] [ text o.label ])
                    )

              else
                text ""
            ]
        , td []
            [ button
                [ Attr.class "btn btn-ghost btn-sm btn-square text-error"
                , Events.onClick (config.onRemoveRow idx)
                ]
                [ text "×" ]
            ]
        ]
