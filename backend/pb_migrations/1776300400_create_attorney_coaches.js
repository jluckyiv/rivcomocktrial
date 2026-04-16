/// <reference path="../pb_data/types.d.ts" />
// Attorney coaches for a team. Names and contact info only.
// No system access — RCOE communicates with attorneys through the
// Bar Association; attorney coach system access is deferred (ADR-007).
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");

    const collection = new Collection({
      type: "base",
      name: "attorney_coaches",
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
          type: "text",
          name: "name",
          required: true,
          max: 200,
        },
        {
          type: "text",
          name: "contact",
          required: false,
          max: 300,
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
    const collection = app.findCollectionByNameOrId("attorney_coaches");
    app.delete(collection);
  }
);
