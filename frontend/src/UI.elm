module UI exposing
    ( actionButton
    , actionRow
    , alert
    , backLinkTitleBar
    , badge
    , buttonRow
    , cancelButton
    , card
    , cardActions
    , cardBody
    , cardGrid
    , cardHeader
    , cardTitle
    , centeredNote
    , centeredPage
    , dataTable
    , empty
    , emptyState
    , notAsked
    , error
    , errorList
    , errorSubmitButton
    , filtersRow
    , filterSelect
    , formColumns
    , formField
    , hint
    , iconButton
    , inlineLink
    , inlineLoading
    , interactiveCell
    , loading
    , loadingActionButton
    , narrowPage
    , note
    , numberField
    , pageHeading
    , passwordField
    , primaryButton
    , rowActionButton
    , sectionTitle
    , selectField
    , smallButton
    , smallCancelButton
    , smallOutlineButton
    , smallPrimaryLink
    , smallPrimarySubmit
    , statCard
    , tableWrap
    , tabs
    , textField
    , textareaField
    , titleBar
    )

{-| DaisyUI view helpers. All page modules must use these instead of
writing raw `Html.Attributes.class` patterns directly. If a helper you
need does not exist here, add it before using it in a page.

`titleBar` takes `actions : List { label, msg }`. First action =
`btn-primary`; subsequent = `btn-outline`.

-}

import Html exposing (Html, a, button, div, h1, h2, input, label, li, option, p, select, span, table, tbody, td, text, textarea, th, thead, tr, ul)
import Html.Attributes as Attr
import Html.Events as Events



-- LAYOUT


{-| Page title bar: title on the left, action buttons on the right.

The first action renders as `btn-primary`; subsequent actions render
as `btn-outline`. Pass an empty list for no buttons.

    UI.titleBar
        { title = "Schools"
        , actions =
            [ { label = "New School", msg = ShowCreateForm }
            , { label = "Bulk Import", msg = ShowBulkImport }
            ]
        }

-}
titleBar :
    { title : String
    , actions : List { label : String, msg : msg }
    }
    -> Html msg
titleBar config =
    div [ Attr.class "flex justify-between items-center mb-6" ]
        [ h1 [ Attr.class "text-2xl font-bold" ] [ text config.title ]
        , div [ Attr.class "flex gap-2" ]
            (List.indexedMap
                (\i action ->
                    button
                        [ Attr.class
                            (if i == 0 then
                                "btn btn-primary"

                             else
                                "btn btn-outline"
                            )
                        , Events.onClick action.msg
                        ]
                        [ text action.label ]
                )
                config.actions
            )
        ]


{-| Page title bar with a back link on the right instead of action buttons.

    UI.backLinkTitleBar
        { title = "Round 1 (Preliminary)"
        , backLabel = "Back to Rounds"
        , backHref = "/admin/rounds"
        }

-}
backLinkTitleBar :
    { title : String
    , backLabel : String
    , backHref : String
    }
    -> Html msg
backLinkTitleBar config =
    div [ Attr.class "flex justify-between items-center mb-6" ]
        [ h1 [ Attr.class "text-2xl font-bold" ] [ text config.title ]
        , a [ Attr.class "btn btn-ghost", Attr.href config.backHref ]
            [ text config.backLabel ]
        ]


{-| Two-column grid for side-by-side form fields.

    UI.formColumns
        [ UI.textField { label = "Name", ... }
        , UI.textField { label = "District", ... }
        ]

-}
formColumns : List (Html msg) -> Html msg
formColumns children =
    div [ Attr.class "grid grid-cols-1 md:grid-cols-2 gap-4" ] children


{-| Centered full-screen page layout. Use for login and auth pages.

    UI.centeredPage
        [ UI.card [ ... ] ]

-}
centeredPage : List (Html msg) -> Html msg
centeredPage children =
    div [ Attr.class "min-h-screen flex items-center justify-center" ]
        [ div [ Attr.class "w-full max-w-sm" ] children ]


{-| Narrow centered content wrapper. Use for form-heavy public pages like registration.

    UI.narrowPage
        [ UI.pageHeading "Teacher Coach Registration"
        , viewForm model
        ]

-}
narrowPage : List (Html msg) -> Html msg
narrowPage children =
    div [ Attr.class "max-w-lg mx-auto" ] children


{-| Top-level page heading for public pages.

    UI.pageHeading "Register"

-}
pageHeading : String -> Html msg
pageHeading t =
    h1 [ Attr.class "text-2xl font-bold mb-6" ] [ text t ]


{-| Horizontal row of filter selects with consistent spacing.

    UI.filtersRow
        [ UI.filterSelect { ... }
        , UI.filterSelect { ... }
        ]

-}
filtersRow : List (Html msg) -> Html msg
filtersRow children =
    div [ Attr.class "flex gap-4 mb-4" ] children



-- CARD


{-| Card container. Pass cardTitle and cardBody as children.

    UI.card [ UI.cardTitle "New School", UI.cardBody [ ... ] ]

-}
card : List (Html msg) -> Html msg
card children =
    div [ Attr.class "card bg-base-100 shadow-sm mb-6" ] children


{-| Card title text.
-}
cardTitle : String -> Html msg
cardTitle t =
    h2 [ Attr.class "card-title" ] [ text t ]


{-| Card body wrapper.
-}
cardBody : List (Html msg) -> Html msg
cardBody children =
    div [ Attr.class "card-body" ] children


{-| Card header: title on the left, action (e.g. close button) on the right.

    UI.cardHeader
        [ UI.cardTitle "Title"
        , UI.iconButton ClosePanel (text "×")
        ]

-}
cardHeader : List (Html msg) -> Html msg
cardHeader children =
    div [ Attr.class "flex items-center justify-between" ] children


{-| Card actions row: right-aligned, with top margin.

    UI.cardActions
        [ UI.smallPrimaryLink "Register" (Route.Path.href path) ]

-}
cardActions : List (Html msg) -> Html msg
cardActions children =
    div [ Attr.class "card-actions justify-end mt-2" ] children


{-| Responsive 3-column card grid. Use for role-selection or feature pages.

    UI.cardGrid [ roleCard { ... }, roleCard { ... }, roleCard { ... } ]

-}
cardGrid : List (Html msg) -> Html msg
cardGrid children =
    div [ Attr.class "grid grid-cols-1 md:grid-cols-3 gap-4" ] children



-- TABLE


{-| Full-width zebra-striped data table.

    UI.dataTable
        { columns = [ "Name", "District", "Actions" ]
        , rows = schools
        , rowView = viewRow model.deleting
        }

-}
dataTable :
    { columns : List String
    , rows : List a
    , rowView : a -> Html msg
    }
    -> Html msg
dataTable config =
    div [ Attr.class "overflow-x-auto" ]
        [ table [ Attr.class "table table-zebra w-full" ]
            [ thead []
                [ tr [] (List.map (\col -> th [] [ text col ]) config.columns) ]
            , tbody [] (List.map config.rowView config.rows)
            ]
        ]



{-| Overflow wrapper for complex tables that can't use `dataTable`.

    UI.tableWrap
        (table [ Attr.class "table table-sm table-zebra w-full" ] [...])

-}
tableWrap : Html msg -> Html msg
tableWrap content =
    div [ Attr.class "overflow-x-auto" ] [ content ]


{-| Interactive table cell for matrix/grid selection UIs.

    UI.interactiveCell isSelected (SelectCell id) (UI.badge { ... })

-}
interactiveCell : Bool -> msg -> Html msg -> Html msg
interactiveCell isSelected clickMsg content =
    td
        [ Attr.class "text-center cursor-pointer hover:bg-base-300"
        , Attr.classList [ ( "bg-base-300 ring-2 ring-primary", isSelected ) ]
        , Events.onClick clickMsg
        ]
        [ content ]



-- FORM FIELDS


{-| Labeled form field wrapper with flexible children.

Use when the input is not a simple text/number/password field (e.g. a
select with custom options, or a field with helper text beneath it).

    UI.formField "School"
        [ select [ ... ] [ ... ]
        , UI.note "Select your school"
        ]

-}
formField : String -> List (Html msg) -> Html msg
formField labelText children =
    label [ Attr.class "form-control w-full" ]
        (div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text labelText ] ]
            :: children
        )


{-| Labeled text input.

    UI.textField
        { label = "Name"
        , value = formData.name
        , onInput = FormNameChanged
        , required = True
        }

-}
textField :
    { label : String
    , value : String
    , onInput : String -> msg
    , required : Bool
    }
    -> Html msg
textField config =
    label [ Attr.class "form-control w-full" ]
        [ div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text config.label ] ]
        , input
            [ Attr.class "input input-bordered w-full"
            , Attr.value config.value
            , Events.onInput config.onInput
            , Attr.required config.required
            ]
            []
        ]


{-| Password input. Same as textField but always type="password".

    UI.passwordField
        { label = "Password"
        , value = model.password
        , onInput = PasswordChanged
        }

-}
passwordField :
    { label : String
    , value : String
    , onInput : String -> msg
    }
    -> Html msg
passwordField config =
    label [ Attr.class "form-control w-full" ]
        [ div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text config.label ] ]
        , input
            [ Attr.class "input input-bordered w-full"
            , Attr.type_ "password"
            , Attr.value config.value
            , Events.onInput config.onInput
            ]
            []
        ]


{-| Labeled textarea input.

    UI.textareaField
        { label = "Bulk Import"
        , value = bulkText
        , onInput = BulkTextChanged
        , rows = 6
        , placeholder = "Lincoln High, Riverside USD"
        }

-}
textareaField :
    { label : String
    , value : String
    , onInput : String -> msg
    , rows : Int
    , placeholder : String
    }
    -> Html msg
textareaField config =
    label [ Attr.class "form-control w-full" ]
        [ div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text config.label ] ]
        , textarea
            [ Attr.class "textarea textarea-bordered w-full"
            , Attr.value config.value
            , Events.onInput config.onInput
            , Attr.rows config.rows
            , Attr.placeholder config.placeholder
            ]
            []
        ]



-- BUTTONS


{-| Primary submit button. Shows a spinner when loading is True.

    UI.primaryButton { label = "Save", loading = isSaving }

-}
primaryButton : { label : String, loading : Bool } -> Html msg
primaryButton config =
    button
        [ Attr.class "btn btn-primary"
        , Attr.type_ "submit"
        , Attr.disabled config.loading
        ]
        (if config.loading then
            [ span [ Attr.class "loading loading-spinner loading-sm" ] []
            , text config.label
            ]

         else
            [ text config.label ]
        )


{-| Ghost cancel button. Always type="button" to avoid form submission.

    UI.cancelButton CancelForm

-}
cancelButton : msg -> Html msg
cancelButton msg =
    button
        [ Attr.class "btn btn-ghost"
        , Attr.type_ "button"
        , Events.onClick msg
        ]
        [ text "Cancel" ]


{-| Small ghost cancel button for compact inline forms.

    UI.smallCancelButton CancelCoCoachForm

-}
smallCancelButton : msg -> Html msg
smallCancelButton msg =
    button
        [ Attr.class "btn btn-sm btn-ghost"
        , Attr.type_ "button"
        , Events.onClick msg
        ]
        [ text "Cancel" ]


{-| Small primary submit button for compact inline forms.

    UI.smallPrimarySubmit "Add"

-}
smallPrimarySubmit : String -> Html msg
smallPrimarySubmit label =
    button
        [ Attr.class "btn btn-sm btn-primary"
        , Attr.type_ "submit"
        ]
        [ text label ]


{-| Error-colored full-size submit button. Use for destructive confirmation forms.

    UI.errorSubmitButton "Confirm Withdrawal"

-}
errorSubmitButton : String -> Html msg
errorSubmitButton label =
    button
        [ Attr.class "btn btn-error"
        , Attr.type_ "submit"
        ]
        [ text label ]


{-| Action button with onClick. Use for non-submit workflow buttons.
Pass a DaisyUI variant: "info", "success", "ghost", "primary", "error", etc.

    UI.actionButton { label = "Generate", variant = "info", msg = Generate }

-}
actionButton :
    { label : String
    , variant : String
    , msg : msg
    }
    -> Html msg
actionButton config =
    button
        [ Attr.class ("btn btn-" ++ config.variant)
        , Events.onClick config.msg
        ]
        [ text config.label ]


{-| Action button with onClick and loading state.

Pass `disabled = True` to disable for reasons other than loading (e.g. empty field).

    UI.loadingActionButton
        { label = "Import"
        , variant = "info"
        , loading = model.saving
        , disabled = String.trim model.text == ""
        , msg = BulkImport
        }

-}
loadingActionButton :
    { label : String
    , variant : String
    , loading : Bool
    , disabled : Bool
    , msg : msg
    }
    -> Html msg
loadingActionButton config =
    button
        [ Attr.class ("btn btn-" ++ config.variant)
        , Events.onClick config.msg
        , Attr.disabled (config.loading || config.disabled)
        ]
        (if config.loading then
            [ span [ Attr.class "loading loading-spinner loading-sm" ] []
            , text config.label
            ]

         else
            [ text config.label ]
        )


{-| Small action button (btn-sm). Use for table row actions and inline controls.
Pass a DaisyUI variant: "primary", "ghost", "success", "error", etc.

    UI.smallButton { label = "Edit", variant = "primary", msg = EditItem id }

-}
smallButton :
    { label : String
    , variant : String
    , msg : msg
    }
    -> Html msg
smallButton config =
    button
        [ Attr.class ("btn btn-sm btn-" ++ config.variant)
        , Events.onClick config.msg
        ]
        [ text config.label ]


{-| Small outline row-action button with optional loading spinner.
Use for table row actions (Edit, Delete, Approve, Reject).

    UI.rowActionButton { label = "Delete", variant = "error", loading = deleting == Just id, msg = Delete id }
    UI.rowActionButton { label = "Edit", variant = "info", loading = False, msg = Edit item }

-}
rowActionButton :
    { label : String
    , variant : String
    , loading : Bool
    , msg : msg
    }
    -> Html msg
rowActionButton config =
    button
        [ Attr.class ("btn btn-sm btn-outline btn-" ++ config.variant)
        , Events.onClick config.msg
        , Attr.disabled config.loading
        ]
        (if config.loading then
            [ span [ Attr.class "loading loading-spinner loading-sm" ] [] ]

         else
            [ text config.label ]
        )


{-| Small outline button (btn-sm btn-outline). Pass a variant or "" for no variant color.

    UI.smallOutlineButton { label = "Edit", variant = "info", msg = EditItem id }
    UI.smallOutlineButton { label = "Delete", variant = "error", msg = DeleteItem id }
    UI.smallOutlineButton { label = "+ Add", variant = "", msg = ShowForm }

-}
smallOutlineButton :
    { label : String
    , variant : String
    , msg : msg
    }
    -> Html msg
smallOutlineButton config =
    let
        variantClass =
            if config.variant == "" then
                ""

            else
                " btn-" ++ config.variant
    in
    button
        [ Attr.class ("btn btn-sm btn-outline" ++ variantClass)
        , Events.onClick config.msg
        ]
        [ text config.label ]


{-| Square ghost icon button (btn-ghost btn-sm btn-square). Pass any HTML as content.

    UI.iconButton ClosePanel (text "×")

-}
iconButton : msg -> Html msg -> Html msg
iconButton msg content =
    button
        [ Attr.class "btn btn-ghost btn-sm btn-square"
        , Events.onClick msg
        ]
        [ content ]


{-| Small primary link styled as a button. Use for `<a>` elements that look like buttons.

    UI.smallPrimaryLink "Register" (Route.Path.href Route.Path.Register_TeacherCoach)

-}
smallPrimaryLink : String -> Html.Attribute msg -> Html msg
smallPrimaryLink label hrefAttr =
    a [ Attr.class "btn btn-primary btn-sm", hrefAttr ] [ text label ]


{-| Inline hyperlink with DaisyUI `link` styling.

    UI.inlineLink "Login here" (Route.Path.href Route.Path.Team_Login)

-}
inlineLink : String -> Html.Attribute msg -> Html msg
inlineLink label hrefAttr =
    a [ Attr.class "link", hrefAttr ] [ text label ]


{-| Horizontal button row without top margin. Use for inline action groups.

    UI.buttonRow
        [ UI.smallButton { label = "Approve", variant = "success", msg = Approve id }
        , UI.smallButton { label = "Reject", variant = "error", msg = Reject id }
        ]

-}
buttonRow : List (Html msg) -> Html msg
buttonRow children =
    div [ Attr.class "flex gap-2" ] children


{-| Horizontal button row with top margin. Use at the end of forms and sections.

    UI.actionRow
        [ UI.primaryButton { label = "Save", loading = False }
        , UI.cancelButton CancelForm
        ]

-}
actionRow : List (Html msg) -> Html msg
actionRow children =
    div [ Attr.class "flex gap-2 mt-4" ] children



-- TABS


{-| DaisyUI tabs with border style. Pass the active tab's `active = True`.

    UI.tabs
        [ { label = "Dropdown", active = model.mode == Dropdown, msg = SwitchMode Dropdown }
        , { label = "Bulk Text", active = model.mode == BulkText, msg = SwitchMode BulkText }
        ]

-}
tabs : List { label : String, active : Bool, msg : msg } -> Html msg
tabs items =
    div [ Attr.class "tabs tabs-border mb-4" ]
        (List.map
            (\item ->
                a
                    [ Attr.class
                        (if item.active then
                            "tab tab-active"

                         else
                            "tab"
                        )
                    , Events.onClick item.msg
                    ]
                    [ text item.label ]
            )
            items
        )



-- STATUS


{-| Full-width loading spinner.
-}
loading : Html msg
loading =
    div [ Attr.class "flex justify-center p-8" ]
        [ span [ Attr.class "loading loading-spinner loading-md" ] [] ]


{-| Inline loading indicator with a label. Use for saving/submitting states.

    UI.inlineLoading "Saving..."

-}
inlineLoading : String -> Html msg
inlineLoading label =
    div [ Attr.class "flex items-center gap-2 mt-4" ]
        [ span [ Attr.class "loading loading-spinner loading-sm" ] []
        , text label
        ]


{-| Single error message alert. For data fetch errors.
-}
error : String -> Html msg
error msg =
    div [ Attr.class "alert alert-error mb-4" ]
        [ text msg ]


{-| List of validation error messages. Hidden when list is empty.
-}
errorList : List String -> Html msg
errorList errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "alert alert-error mb-4" ]
            [ ul [ Attr.class "list-disc list-inside" ]
                (List.map (\e -> li [] [ text e ]) errors)
            ]


{-| Alert box with a DaisyUI variant. Includes bottom margin.
Pass "info", "warning", "success", or "error" as the variant.

    UI.alert { variant = "warning" } [ text "Round already has pairings." ]
    UI.alert { variant = "info" } [ text "Registration is not currently open." ]

-}
alert : { variant : String } -> List (Html msg) -> Html msg
alert config children =
    div [ Attr.class ("alert alert-" ++ config.variant ++ " mb-4") ] children


{-| Centered message for empty collection state.
-}
emptyState : String -> Html msg
emptyState msg =
    div [ Attr.class "text-center text-base-content/50 py-8" ]
        [ p [] [ text msg ] ]


notAsked : String -> Html msg
notAsked msg =
    div [ Attr.class "text-center text-base-content/50 py-8" ]
        [ p [] [ text msg ] ]


empty : Html msg
empty =
    text ""



-- SELECT FIELDS


{-| Labeled select dropdown for use in forms.

Pass the placeholder as the first option with an empty value:

    UI.selectField
        { label = "Tournament"
        , value = formData.tournament
        , onInput = FormTournamentChanged
        , options =
            { value = "", label = "Select tournament..." }
                :: List.map (\t -> { value = t.id, label = t.name }) tournaments
        }

-}
selectField :
    { label : String
    , value : String
    , onInput : String -> msg
    , options : List { value : String, label : String }
    }
    -> Html msg
selectField config =
    label [ Attr.class "form-control w-full" ]
        [ div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text config.label ] ]
        , select
            [ Attr.class "select select-bordered w-full"
            , Events.onInput config.onInput
            ]
            (List.map
                (\opt ->
                    option
                        [ Attr.value opt.value
                        , Attr.selected (config.value == opt.value)
                        ]
                        [ text opt.label ]
                )
                config.options
            )
        ]


{-| Number input field. Use for year, round number, team number, etc.

    UI.numberField
        { label = "Year"
        , value = formData.year
        , onInput = FormYearChanged
        , required = True
        }

-}
numberField :
    { label : String
    , value : String
    , onInput : String -> msg
    , required : Bool
    }
    -> Html msg
numberField config =
    label [ Attr.class "form-control w-full" ]
        [ div [ Attr.class "label" ]
            [ span [ Attr.class "label-text" ] [ text config.label ] ]
        , input
            [ Attr.class "input input-bordered w-full"
            , Attr.type_ "number"
            , Attr.value config.value
            , Events.onInput config.onInput
            , Attr.required config.required
            ]
            []
        ]


{-| Compact filter select for placement above a data table.

    UI.filterSelect
        { label = "Tournament:"
        , value = model.filterTournament
        , onInput = FilterTournamentChanged
        , options =
            { value = "", label = "All Tournaments" }
                :: List.map (\t -> { value = t.id, label = t.name }) model.tournaments
        }

-}
filterSelect :
    { label : String
    , value : String
    , onInput : String -> msg
    , options : List { value : String, label : String }
    }
    -> Html msg
filterSelect config =
    div [ Attr.class "flex items-center gap-2 mb-4" ]
        [ if config.label /= "" then
            span [ Attr.class "text-sm text-base-content/70" ] [ text config.label ]

          else
            text ""
        , select
            [ Attr.class "select select-bordered select-sm"
            , Events.onInput config.onInput
            ]
            (List.map
                (\opt ->
                    option
                        [ Attr.value opt.value
                        , Attr.selected (config.value == opt.value)
                        ]
                        [ text opt.label ]
                )
                config.options
            )
        ]



-- BADGE


{-| Colored status badge. Variant maps to DaisyUI badge variants:
`"neutral"`, `"info"`, `"success"`, `"warning"`, `"error"`, `"ghost"`.

    UI.badge { label = "Pending", variant = "warning" }

    UI.badge { label = "Active", variant = "success" }

-}
badge : { label : String, variant : String } -> Html msg
badge config =
    span [ Attr.class ("badge badge-" ++ config.variant) ] [ text config.label ]


{-| Small muted note beneath a form field.
-}
note : String -> Html msg
note t =
    p [ Attr.class "text-sm text-base-content/60 mt-1" ] [ text t ]


{-| Inline hint text in muted gray. Use for labels or contextual notes.
-}
hint : String -> Html msg
hint t =
    span [ Attr.class "text-sm text-base-content/70" ] [ text t ]


{-| Section heading (h2). Use above data tables or content groups.

    UI.sectionTitle "Current Pairings"

-}
sectionTitle : String -> Html msg
sectionTitle t =
    h2 [ Attr.class "text-lg font-semibold mb-3" ] [ text t ]


{-| Centered small paragraph. Use for sign-in/sign-up prompts.

    UI.centeredNote
        [ text "Already have an account? "
        , UI.inlineLink "Login here" (Route.Path.href Route.Path.Team_Login)
        ]

-}
centeredNote : List (Html msg) -> Html msg
centeredNote children =
    p [ Attr.class "text-center text-sm" ] children


{-| DaisyUI stat component. Use inside a `div [ class "stats shadow w-full" ]`.

`variant` maps to a DaisyUI text-color utility: `"warning"`, `"success"`,
`"error"`, `"info"`, `"neutral"`. Pass `""` for the default base color.

    div [ Attr.class "stats shadow w-full" ]
        [ UI.statCard { label = "Pending Approvals", value = "3", variant = "warning" }
        , UI.statCard { label = "Active Teams", value = "12", variant = "success" }
        ]

-}
statCard : { label : String, value : String, variant : String } -> Html msg
statCard config =
    div [ Attr.class "stat" ]
        [ div [ Attr.class "stat-title" ] [ text config.label ]
        , div
            [ Attr.class
                (if config.variant == "" then
                    "stat-value"

                 else
                    "stat-value text-" ++ config.variant
                )
            ]
            [ text config.value ]
        ]
