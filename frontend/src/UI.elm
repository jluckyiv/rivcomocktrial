module UI exposing
    ( cancelButton
    , card
    , cardBody
    , cardTitle
    , dataTable
    , empty
    , emptyState
    , error
    , errorList
    , formColumns
    , loading
    , primaryButton
    , textareaField
    , textField
    , titleBar
    )

{-| DaisyUI view helpers. All page modules must use these instead of
writing raw Html.Attributes.class patterns directly. If a helper you
need does not exist here, add it before using it in a page.
-}

import Html exposing (Html, button, div, h1, h2, input, label, li, p, span, table, tbody, td, text, textarea, th, thead, tr, ul)
import Html.Attributes as Attr
import Html.Events as Events



-- LAYOUT


{-| Page title bar: title on the left, optional primary action on the right.

    UI.titleBar
        { title = "Schools"
        , action = Just { label = "New School", msg = ShowCreateForm }
        }

-}
titleBar :
    { title : String
    , action : Maybe { label : String, msg : msg }
    }
    -> Html msg
titleBar config =
    div [ Attr.class "flex justify-between items-center mb-6" ]
        [ h1 [ Attr.class "text-2xl font-bold" ] [ text config.title ]
        , case config.action of
            Nothing ->
                text ""

            Just action ->
                button
                    [ Attr.class "btn btn-primary"
                    , Events.onClick action.msg
                    ]
                    [ text action.label ]
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


{-| Card title text. -}
cardTitle : String -> Html msg
cardTitle t =
    h2 [ Attr.class "card-title" ] [ text t ]


{-| Card body wrapper. -}
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


{-| Full-width loading spinner. -}
loading : Html msg
loading =
    div [ Attr.class "flex justify-center p-8" ]
        [ span [ Attr.class "loading loading-spinner loading-md" ] [] ]


{-| Single error message alert. For data fetch errors. -}
error : String -> Html msg
error msg =
    div [ Attr.class "alert alert-error mb-4" ]
        [ text msg ]


{-| List of validation error messages. Hidden when list is empty. -}
errorList : List String -> Html msg
errorList errors =
    if List.isEmpty errors then
        text ""

    else
        div [ Attr.class "alert alert-error mb-4" ]
            [ ul [ Attr.class "list-disc list-inside" ]
                (List.map (\e -> li [] [ text e ]) errors)
            ]


{-| Centered message for empty collection state. -}
emptyState : String -> Html msg
emptyState msg =
    div [ Attr.class "text-center text-base-content/50 py-8" ]
        [ p [] [ text msg ] ]


{-| Renders nothing. Use for NotAsked RemoteData state. -}
empty : Html msg
empty =
    text ""
