module NoPbOrApiInMigratedPages exposing (rule)

{-| Forbids `import Api` and `import Pb` in pages that have been
migrated to the new architecture (ADR-012).

The `stillOnApi` list is the per-page allowlist of pages that have
NOT yet been migrated. As each slice ships, the page's module name is
removed from this list. From that point on, the rule fails if the
page imports `Api` or `Pb` directly. Migrated pages must call typed
network functions on entity modules instead (e.g. `School.list`,
`School.create`).

When `stillOnApi` reaches `[]`, no page imports `Api` or `Pb`. At
that point `Api.elm` has no callers and is deleted; `Pb.elm` is
imported only by entity modules.

To roll back a page (rare): add it back to `stillOnApi` and explain
why in the PR description.

-}

import Elm.Syntax.Import exposing (Import)
import Elm.Syntax.Module as Module exposing (Module)
import Elm.Syntax.ModuleName exposing (ModuleName)
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Error, Rule)


{-| Pages still permitted to import `Api` or `Pb`.

The list starts with every page in the codebase. Shrink it one entry
per slice as pages are migrated. Do not add new entries; new pages
are written to the new architecture from the start.

-}
stillOnApi : List ModuleName
stillOnApi =
    [ [ "Pages", "Admin" ]
    , [ "Pages", "Admin", "CaseCharacters" ]
    , [ "Pages", "Admin", "Courtrooms" ]
    , [ "Pages", "Admin", "EligibilityRequests" ]
    , [ "Pages", "Admin", "Login" ]
    , [ "Pages", "Admin", "Pairings" ]
    , [ "Pages", "Admin", "Registrations" ]
    , [ "Pages", "Admin", "Rosters" ]
    , [ "Pages", "Admin", "Rounds" ]
    , [ "Pages", "Admin", "Schools" ]
    , [ "Pages", "Admin", "Students" ]
    , [ "Pages", "Admin", "Teams" ]
    , [ "Pages", "Admin", "Tournaments" ]
    , [ "Pages", "Admin", "Trials" ]
    , [ "Pages", "Home_" ]
    , [ "Pages", "Register" ]
    , [ "Pages", "Register", "Pending" ]
    , [ "Pages", "Register", "TeacherCoach" ]
    , [ "Pages", "Team", "Login" ]
    , [ "Pages", "Team", "Manage" ]
    , [ "Pages", "Team", "Rosters" ]
    ]


rule : Rule
rule =
    Rule.newModuleRuleSchema "NoPbOrApiInMigratedPages" []
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.withImportVisitor importVisitor
        |> Rule.fromModuleRuleSchema


moduleDefinitionVisitor :
    Node Module
    -> ModuleName
    -> ( List (Error {}), ModuleName )
moduleDefinitionVisitor node _ =
    ( [], Module.moduleName (Node.value node) )


importVisitor :
    Node Import
    -> ModuleName
    -> ( List (Error {}), ModuleName )
importVisitor node moduleName =
    let
        imp =
            Node.value node

        importedModule =
            Node.value imp.moduleName

        isPage =
            List.head moduleName == Just "Pages"

        isMigrated =
            isPage && not (List.member moduleName stillOnApi)

        isForbidden =
            importedModule == [ "Api" ] || importedModule == [ "Pb" ]
    in
    if isMigrated && isForbidden then
        ( [ Rule.error
                { message =
                    "Migrated page must not import "
                        ++ String.join "." importedModule
                , details =
                    [ "This page has been migrated to use domain types directly. It must not reach into the wire-format layer (`Api`) or the port-mechanics module (`Pb`)."
                    , "Use the entity module's typed network functions instead — e.g. `School.list { onResponse = GotSchools }` rather than `Pb.adminList { collection = \"schools\", ... } |> Pb.decodeList Api.schoolDecoder`."
                    , "If you need to roll this page back, add it to `stillOnApi` in `frontend/review/src/NoPbOrApiInMigratedPages.elm` and explain why in the PR description."
                    , "See `docs/elm-conventions.md` and `docs/refactor-process.md`."
                    ]
                }
                (Node.range node)
          ]
        , moduleName
        )

    else
        ( [], moduleName )
