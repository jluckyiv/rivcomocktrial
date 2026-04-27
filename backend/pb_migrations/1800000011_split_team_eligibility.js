/// <reference path="../pb_data/types.d.ts" />
// Split enrollment from eligibility.
//
// Introduces tournaments_teams: a many-to-many join between tournaments
// and teams that tracks per-tournament eligibility status. Replaces
// teams.status, which conflated two distinct concepts:
//
//   - Enrollment: a coach or team exists in the system (one-time, durable).
//   - Eligibility: a team is approved to compete in a specific tournament
//     (per-tournament, resets each year).
//
// Migration steps:
//   1. Create tournaments_teams collection.
//   2. Backfill: map existing teams.status → tournaments_teams.status.
//   3. Drop teams.status field.
//
// Status mapping (forward):
//   teams.status pending    → tournaments_teams.status pending
//   teams.status active     → tournaments_teams.status eligible
//   teams.status withdrawn  → tournaments_teams.status withdrawn
//   teams.status rejected   → tournaments_teams.status ineligible
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");
    const tournaments = app.findCollectionByNameOrId("tournaments");

    // 1. Create tournaments_teams collection.
    const collection = new Collection({
      type: "base",
      name: "tournaments_teams",
      listRule: "team.coaches ~ @request.auth.id",
      viewRule: "team.coaches ~ @request.auth.id",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "team",
          collectionId: teams.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "tournament",
          collectionId: tournaments.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "status",
          values: ["pending", "eligible", "ineligible", "withdrawn"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "autodate",
          name: "created",
          onCreate: true,
          onUpdate: false,
        },
        {
          type: "autodate",
          name: "updated",
          onCreate: true,
          onUpdate: true,
        },
      ],
    });
    app.save(collection);

    // Unique index: one eligibility record per team per tournament.
    app
      .db()
      .newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_tournaments_teams_team_tournament " +
          "ON tournaments_teams (team, tournament)"
      )
      .execute();

    // 2. Backfill from existing teams.
    const statusMap = {
      pending: "pending",
      active: "eligible",
      withdrawn: "withdrawn",
      rejected: "ineligible",
    };

    const existingTeams = app.findAllRecords("teams");
    const tournamentsTeams = app.findCollectionByNameOrId("tournaments_teams");
    let backfilled = 0;
    let skipped = 0;

    for (const team of existingTeams) {
      const tournamentId = team.get("tournament");
      if (!tournamentId) {
        console.warn(
          "[migration 1800000011] Skipping team " +
            team.id +
            " — no tournament FK."
        );
        skipped++;
        continue;
      }

      const rawStatus = team.get("status") || "pending";
      const eligibility = statusMap[rawStatus] || "pending";

      const row = new Record(tournamentsTeams);
      row.set("team", team.id);
      row.set("tournament", tournamentId);
      row.set("status", eligibility);

      try {
        app.save(row);
        backfilled++;
      } catch (err) {
        console.warn(
          "[migration 1800000011] Failed to backfill team " +
            team.id +
            ": " +
            err
        );
        skipped++;
      }
    }

    console.log(
      "[migration 1800000011] Backfilled " +
        backfilled +
        " tournaments_teams rows; skipped " +
        skipped +
        "."
    );

    // 3. Drop teams.status field.
    teams.fields.removeByName("status");
    app.save(teams);
  },

  // Down: restore teams.status and drop tournaments_teams.
  (app) => {
    // Re-add teams.status with the original four values.
    const teams = app.findCollectionByNameOrId("teams");
    teams.fields.addMarshaledJSON({
      type: "select",
      name: "status",
      values: ["pending", "active", "withdrawn", "rejected"],
      maxSelect: 1,
      required: false,
    });
    app.save(teams);

    // Reverse-map eligibility back to team status.
    const reverseMap = {
      pending: "pending",
      eligible: "active",
      ineligible: "rejected",
      withdrawn: "withdrawn",
    };

    try {
      const rows = app.findAllRecords("tournaments_teams");
      for (const row of rows) {
        const teamId = row.get("team");
        const eligibility = row.get("status") || "pending";
        const teamStatus = reverseMap[eligibility] || "pending";
        try {
          const team = app.findRecordById("teams", teamId);
          team.set("status", teamStatus);
          app.save(team);
        } catch (err) {
          console.warn(
            "[migration 1800000011 down] Failed to restore status for team " +
              teamId +
              ": " +
              err
          );
        }
      }
    } catch (_) {
      // tournaments_teams may already be gone or empty — that's fine.
    }

    // Drop tournaments_teams.
    try {
      const collection = app.findCollectionByNameOrId("tournaments_teams");
      app.delete(collection);
    } catch (_) {
      // already gone
    }
  }
);
