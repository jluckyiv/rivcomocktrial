/// <reference path="../pb_data/types.d.ts" />
// Multi-coach teams:
// - Rename teams.coach (single) → teams.coaches (multi-relation)
// - Drop co_coaches collection (superseded by multi-relation)
// - Update all collection access rules: `coach =` → `coaches ~`
// - Add unique index on (name, school, tournament)
migrate(
  (app) => {
    // 1. Rename teams.coach → teams.coaches, allow multiple
    const teams = app.findCollectionByNameOrId("teams");
    const coachField = teams.fields.getByName("coach");
    coachField.name = "coaches";
    coachField.maxSelect = null;
    teams.listRule = "coaches ~ @request.auth.id";
    teams.viewRule = "coaches ~ @request.auth.id";
    app.save(teams);

    // 2. Unique index: one team name per school per tournament
    app
      .db()
      .newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_teams_name_school_tournament " +
          "ON teams (name, school, tournament)"
      )
      .execute();

    // 3. Drop co_coaches (superseded)
    try {
      const coCoaches = app.findCollectionByNameOrId("co_coaches");
      app.delete(coCoaches);
    } catch (_) {
      // already gone
    }

    // 4. Update access rules on dependent collections
    const ruleUpdates = [
      {
        name: "eligibility_list_entries",
        rules: {
          listRule: "team.coaches ~ @request.auth.id",
          viewRule: "team.coaches ~ @request.auth.id",
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
          deleteRule: "team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "eligibility_change_requests",
        rules: {
          listRule: "team.coaches ~ @request.auth.id",
          viewRule: "team.coaches ~ @request.auth.id",
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
          deleteRule: "team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "roster_submissions",
        rules: {
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "roster_entries",
        rules: {
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
          deleteRule: "team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "attorney_tasks",
        rules: {
          createRule: "roster_entry.team.coaches ~ @request.auth.id",
          updateRule: "roster_entry.team.coaches ~ @request.auth.id",
          deleteRule: "roster_entry.team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "withdrawal_requests",
        rules: {
          listRule: "team.coaches ~ @request.auth.id",
          viewRule: "team.coaches ~ @request.auth.id",
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
          deleteRule: "team.coaches ~ @request.auth.id",
        },
      },
      {
        name: "attorney_coaches",
        rules: {
          listRule: "team.coaches ~ @request.auth.id",
          viewRule: "team.coaches ~ @request.auth.id",
          createRule: "team.coaches ~ @request.auth.id",
          updateRule: "team.coaches ~ @request.auth.id",
          deleteRule: "team.coaches ~ @request.auth.id",
        },
      },
    ];

    for (const { name, rules } of ruleUpdates) {
      try {
        const col = app.findCollectionByNameOrId(name);
        for (const [key, val] of Object.entries(rules)) {
          col[key] = val;
        }
        app.save(col);
      } catch (err) {
        console.warn(`[multi_coach_teams] Could not update ${name}: ${err}`);
      }
    }
  },
  (app) => {
    // Reverse: coaches → coach (single), restore old rules
    const teams = app.findCollectionByNameOrId("teams");
    const coachesField = teams.fields.getByName("coaches");
    coachesField.name = "coach";
    coachesField.maxSelect = 1;
    teams.listRule = "coach = @request.auth.id";
    teams.viewRule = "coach = @request.auth.id";
    app.save(teams);

    app
      .db()
      .newQuery("DROP INDEX IF EXISTS idx_teams_name_school_tournament")
      .execute();

    const ruleRestores = [
      {
        name: "eligibility_list_entries",
        rules: {
          listRule: "team.coach = @request.auth.id",
          viewRule: "team.coach = @request.auth.id",
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
          deleteRule: "team.coach = @request.auth.id",
        },
      },
      {
        name: "eligibility_change_requests",
        rules: {
          listRule: "team.coach = @request.auth.id",
          viewRule: "team.coach = @request.auth.id",
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
          deleteRule: "team.coach = @request.auth.id",
        },
      },
      {
        name: "roster_submissions",
        rules: {
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
        },
      },
      {
        name: "roster_entries",
        rules: {
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
          deleteRule: "team.coach = @request.auth.id",
        },
      },
      {
        name: "attorney_tasks",
        rules: {
          createRule: "roster_entry.team.coach = @request.auth.id",
          updateRule: "roster_entry.team.coach = @request.auth.id",
          deleteRule: "roster_entry.team.coach = @request.auth.id",
        },
      },
      {
        name: "withdrawal_requests",
        rules: {
          listRule: "team.coach = @request.auth.id",
          viewRule: "team.coach = @request.auth.id",
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
          deleteRule: "team.coach = @request.auth.id",
        },
      },
      {
        name: "attorney_coaches",
        rules: {
          listRule: "team.coach = @request.auth.id",
          viewRule: "team.coach = @request.auth.id",
          createRule: "team.coach = @request.auth.id",
          updateRule: "team.coach = @request.auth.id",
          deleteRule: "team.coach = @request.auth.id",
        },
      },
    ];

    for (const { name, rules } of ruleRestores) {
      try {
        const col = app.findCollectionByNameOrId(name);
        for (const [key, val] of Object.entries(rules)) {
          col[key] = val;
        }
        app.save(col);
      } catch (err) {
        console.warn(`[multi_coach_teams] Could not restore ${name}: ${err}`);
      }
    }
  }
);
