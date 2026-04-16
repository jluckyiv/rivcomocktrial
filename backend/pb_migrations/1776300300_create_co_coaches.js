/// <reference path="../pb_data/types.d.ts" />
// Co-teacher coaches for a team. Names and contact info only.
// System access for co-coaches is deferred — this table is for
// display and communication purposes. No user-account linkage.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");

    const collection = new Collection({
      type: "base",
      name: "co_coaches",
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
          type: "email",
          name: "email",
          required: false,
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
    const collection = app.findCollectionByNameOrId("co_coaches");
    app.delete(collection);
  }
);
