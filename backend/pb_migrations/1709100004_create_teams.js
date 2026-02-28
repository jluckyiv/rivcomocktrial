/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const tournaments = app.findCollectionByNameOrId("tournaments");
    const schools = app.findCollectionByNameOrId("schools");

    const collection = new Collection({
      type: "base",
      name: "teams",
      fields: [
        {
          type: "relation",
          name: "tournament",
          required: true,
          collectionId: tournaments.id,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "school",
          required: true,
          collectionId: schools.id,
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "number",
          name: "team_number",
        },
        {
          type: "text",
          name: "name",
          max: 200,
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
    const collection = app.findCollectionByNameOrId("teams");
    app.delete(collection);
  }
);
