module UI exposing
    ( badge
    , cancelButton
    , card
    , cardBody
    , cardTitle
    , dataTable
    , empty
    , emptyState
    , error
    , errorList
    , filterSelect
    , formColumns
    , loading
    , note
    , numberField
    , primaryButton
    , selectField
    , statCard
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

import Html exposing (Html, button, div, h1, h2, input, label, li, option, p, select, span, table, tbody, text, textarea, th, thead, tr, ul)
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


{-| Two-column grid for side-by-side form fields.

    UI.formColumns
        [ UI.textField { label = "Name", ... }
        , UI.textField { label = "District", ... }
        ]

-}
formColumns : List (Html msg) -> Html msg
formColumns children =
    div [ Attr.class "grid grid-cols-1 md:grid-cols-2 gap-4" ] children



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



-- FORM FIELDS


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
        [ Attr.class
            (if config.loading then
                "btn btn-primary"

             else
                "btn btn-primary"
            )
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



-- STATUS


{-| Full-width loading spinner.
-}
loading : Html msg
loading =
    div [ Attr.class "flex justify-center p-8" ]
        [ span [ Attr.class "loading loading-spinner loading-md" ] [] ]


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


{-| Centered message for empty collection state.
-}
emptyState : String -> Html msg
emptyState msg =
    div [ Attr.class "text-center text-base-content/50 py-8" ]
        [ p [] [ text msg ] ]


{-| Renders nothing. Use for NotAsked RemoteData state.
-}
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


note : String -> Html msg
note t =
    p [ Attr.class "text-sm text-base-content/60 mt-1" ] [ text t ]


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
