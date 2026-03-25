# UI Conventions & Elm View Guide

This section is the authoritative reference for all frontend UI work. Follow it precisely.

## CSS Framework

**DaisyUI 5** (component classes) on top of **Tailwind CSS 4** (utility classes),
integrated via Elm Land's internal Vite build system.

- Theme: DaisyUI themes via `data-theme` attribute on `<html>` in `elm-land.json`
  (e.g., `corporate`, `nord`, `winter`). Catppuccin colors can be ported
  as a custom DaisyUI theme via CSS variables.
- **Never use Bulma classes.** This project has migrated from Bulma to DaisyUI.
- When in doubt about a DaisyUI class, check https://daisyui.com/components/

### Build integration (tiered approach)

Elm Land wraps Vite internally and does not expose `vite.config.js`
(the `elm-land customize` command only covers Elm modules, not build config).
However, Vite auto-detects `postcss.config.mjs` at the project root. We use
this to wire in Tailwind and DaisyUI.

**Try these approaches in order. Use the first one that works.**

#### Approach A — Tailwind v4 + DaisyUI 5 via `@tailwindcss/postcss` (preferred)

Tailwind v4 auto-detects content files — no `tailwind.config.js` needed.
The Elm compiler outputs JS that preserves `Html.Attributes.class` string
literals, so Tailwind should pick up class names from compiled output.

```bash
cd frontend
npm install -D @tailwindcss/postcss postcss daisyui@5
```

`frontend/postcss.config.mjs`:
```js
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
}
```

`frontend/src/app.css`:
```css
@import "tailwindcss";
@plugin "daisyui";
```

In `frontend/src/interop.js`, replace `import "./catppuccin.css"` with
`import "./app.css"`.

In `frontend/elm-land.json`, remove the Bulma CDN `<link>` tag and add
the `data-theme` attribute:
```json
"attributes": {
  "html": { "lang": "en", "data-theme": "corporate" }
}
```

**Verify:** Run `npm run fe:dev`, inspect the page — DaisyUI classes
like `btn btn-primary` should render correctly. If classes appear
unstyled, Tailwind's auto-detection may not be finding `.elm` files.
Move to Approach B.

#### Approach B — Tailwind v3 + DaisyUI 4 via PostCSS with explicit content paths

Proven approach from https://github.com/dz0ny/elm-land-tailwind.
Uses explicit `content` globs to scan `.elm` files for class names.

```bash
cd frontend
npm install -D tailwindcss@3 postcss autoprefixer daisyui@4
```

`frontend/tailwind.config.js`:
```js
module.exports = {
  content: [
    "./src/**/*.{js,elm,ts,css,html}",
    ".elm-land/**/*.{js,elm,ts,css,html}",
  ],
  plugins: [require("daisyui")],
  daisyui: {
    themes: ["corporate", "dark"],
  },
}
```

`frontend/postcss.config.js`:
```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

`frontend/src/app.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Same `interop.js` and `elm-land.json` changes as Approach A.

**Verify:** Same as above. This approach has a known working example
with Elm Land. If it still fails, move to Approach C.

#### Approach C — DaisyUI 5 CDN (escape hatch)

No build integration. Larger payload (34 kB compressed) but zero config.
Use this if the build approaches fail, or as a quick start while
debugging build issues.

In `frontend/elm-land.json`, replace the Bulma `<link>` with:
```json
"link": [
  { "rel": "stylesheet", "href": "https://cdn.jsdelivr.net/npm/daisyui@5/dist/daisyui.css" }
],
"script": [
  { "src": "https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4" }
]
```

No `postcss.config`, no `tailwind.config`, no `app.css` needed.
Tailwind utility classes and DaisyUI component classes both work
immediately. No tree-shaking — all classes are included.

### Reference projects

- https://github.com/dz0ny/elm-land-tailwind (Elm Land + Tailwind v3 via PostCSS)
- https://github.com/gacallea/elm_vite_tailwind_template (raw Elm + Vite + Tailwind v4 + DaisyUI — not Elm Land, but shows the DaisyUI integration pattern)

## Elm View Architecture

### Use `UI.elm` for all view helpers

Never write raw `Html.div [ Attr.class "..." ]` patterns in page modules.
All DaisyUI/Tailwind markup lives in `frontend/src/UI.elm`. Pages call
helper functions. If a helper doesn't exist, add it to `UI.elm` first,
then use it in the page.

```elm
-- WRONG (raw classes in page module):
div [ Attr.class "card bg-base-100 shadow-xl" ]
    [ div [ Attr.class "card-body" ] [ ... ] ]

-- RIGHT (use UI helpers):
UI.card [ UI.cardTitle "Schools", UI.cardBody [ viewTable model ] ]
```

### Component conventions (Elm Land "123s")

For components with internal state (dropdowns, modals, date pickers),
follow Elm Land's opaque-type component pattern:
1. Opaque `Settings` type with a `new` constructor
2. Builder functions for configuration
3. `view` function that takes `Settings` and returns `Html msg`

For stateless view helpers (buttons, fields, tables), use simple
functions in `UI.elm`.

## Admin Page Templates

Every admin CRUD page follows this exact structure. Do not deviate.

### Page layout (top to bottom):

1. **Title bar** — page title on the left, primary action button on the right
2. **Form area** — hidden by default, appears when creating/editing
3. **Data table** — full-width table with inline action buttons per row

```elm
view : Model -> View Msg
view model =
    { title = "Schools"
    , body =
        [ UI.titleBar
            { title = "Schools"
            , actions = [ { label = "New School", msg = ShowCreateForm } ]
            }
        , viewForm model.form
        , viewDataTable model
        ]
    }
```

### Model shape for admin CRUD pages:

```elm
type alias Model =
    { items : RemoteData (List Item)  -- the data
    , form : FormState                -- create/edit form
    , deleting : Maybe String         -- ID of item being deleted
    }
```

No other top-level fields for simple CRUD. If you need extra state
(e.g., bulk import), group it into a named record or custom type.

### FormState pattern (mandatory):

```elm
type FormContext
    = Creating
    | Editing String  -- the record ID

type FormState
    = FormHidden
    | FormOpen FormContext FormData (List String)  -- context, data, errors
    | FormSaving FormContext FormData

-- NEVER use separate booleans:
-- BAD:  { isFormOpen : Bool, isSaving : Bool, formErrors : List String }
-- GOOD: FormState as defined above
```

### RemoteData pattern (mandatory for all async data):

```elm
type RemoteData a
    = NotAsked
    | Loading
    | Succeeded a
    | Failed String
```

Always handle all four states in view functions. Never leave `NotAsked`
or `Loading` unhandled.

## Data Table Conventions

```elm
viewDataTable : Model -> Html Msg
viewDataTable model =
    case model.items of
        NotAsked -> UI.empty
        Loading -> UI.loading
        Failed err -> UI.error err
        Succeeded [] -> UI.emptyState "No schools yet. Add one to get started."
        Succeeded items -> UI.dataTable { columns = [...], rows = items, rowView = viewRow }
```

- Tables are always full-width
- Action buttons in the last column: Edit (outline), Delete (ghost/danger)
- Delete shows loading state on the row being deleted (use `model.deleting`)
- Empty state always includes a helpful message

## Form Conventions

- Forms appear in a card/box below the title bar when FormOpen
- Use `Html.form [ Events.onSubmit SaveItem ]` — never button onClick for submission
- Validation happens client-side in `validateForm` before sending to PocketBase
- Show validation errors in a notification/alert above form fields
- Save button shows loading state when FormSaving
- Cancel button is always available and fires `CancelForm`
- Lay out fields in columns when there are 2+ short fields (e.g., Name + District)

## Type Safety Rules

These rules are non-negotiable. Claude Code must follow them.

1. **Sum types over booleans.** If a value has more than two meaningful
   states, or if two booleans are mutually exclusive, use a custom type.
   ```elm
   -- BAD:
   { isLoading : Bool, hasError : Bool, data : Maybe (List School) }

   -- GOOD:
   { schools : RemoteData (List School) }
   ```

2. **Parse, don't validate (ADR-009).** Domain values are validated at
   the boundary and wrapped in opaque types. Use smart constructors.
   ```elm
   -- BAD:
   if String.length name > 0 then ...

   -- GOOD:
   case School.nameFromString rawName of
       Ok name -> ...
       Err errors -> ...
   ```

3. **No raw strings for IDs.** Use the PocketBase record ID (String)
   but always pair it with context (e.g., `Editing String` not just
   `String`).

4. **Never use `Bool` for UI mode switching.** Use a custom type.
   ```elm
   -- BAD:
   { showBulkImport : Bool }

   -- GOOD:
   type InputMode = SingleEntry | BulkImport
   ```

5. **Msg types are specific.** Never use generic messages like
   `NoOp` or `DoNothing`. Every message describes what happened.

## PocketBase Integration Pattern

All PocketBase calls go through `Pb.elm` ports. Follow this pattern exactly:

```elm
-- In update:
SaveSchool ->
    case model.form of
        FormOpen context formData _ ->
            case validateForm formData of
                Err errors ->
                    ( { model | form = FormOpen context formData errors }, Effect.none )
                Ok validated ->
                    ( { model | form = FormSaving context formData }
                    , Pb.adminCreate { collection = "schools", tag = "save-school", body = Api.encodeSchool validated }
                    )
        _ ->
            ( model, Effect.none )

-- In PbMsg handler, match on tag:
PbMsg value ->
    case Pb.responseTag value of
        Just "save-school" ->
            case Pb.decodeRecord Api.schoolDecoder value of
                Ok school -> -- update model, close form
                Err _ -> -- reopen form with error
        _ ->
            ( model, Effect.none )
```

- Tags must be descriptive: `"save-school"`, `"delete-school"`, `"list-teams"`
- Never use generic tags like `"response"` or `"data"`
- Always handle both `Ok` and `Err` branches

## Public Page Guidelines

Public-facing pages (Home, Register, Login) have more layout freedom
than admin pages, but still use `UI.elm` helpers. For these pages:

- Use DaisyUI hero sections for landing pages
- Center forms in a card with constrained width
- Use the Public layout navbar

## What NOT to Do

- Do not use `elm/html` raw classes in page modules — use `UI.elm`
- Do not add `elm-ui` or `elm-css` — we use DaisyUI class strings
- Do not create separate CSS files — all styling through DaisyUI/Tailwind classes
- Do not use JavaScript for UI behavior — use Elm's TEA (The Elm Architecture)
- Do not default to OOP/JS patterns (event emitters, inheritance, this/self)
- Do not use `Maybe Bool` or `Maybe (Maybe a)` — model the real states
- Do not put view logic in update functions or update logic in view functions
