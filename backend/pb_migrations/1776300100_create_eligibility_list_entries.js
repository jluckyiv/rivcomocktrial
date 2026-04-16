/// <reference path="../pb_data/types.d.ts" />
// Student eligibility list entries for a team's tournament season.
// Coaches add/remove students before the eligibility lock date.
// After lock, entries are read-only and changes go through
// eligibility_change_requests.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");
    const tournaments = app.findCollectionByNameOrId("tournaments");

    const collection = new Collection({
      type: "base",
      name: "eligibility_list_entries",
      // Coaches see and edit only their own team's entries.
      // Admins bypass rules via pbAdmin (superuser).
      listRule: "team.coach = @request.auth.id",
      viewRule: "team.coach = @request.auth.id",
      createRule: "team.coach = @request.auth.id",
      updateRule: "team.coach = @request.auth.id",
      deleteRule: "team.coach = @request.auth.id",
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
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "text",
          name: "name",
          required: true,
          max: 200,
        },
        {
          type: "select",
          name: "status",
          values: ["active", "removed"],
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
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(
      "eligibility_list_entries"
    );
    app.delete(collection);
  }
);
