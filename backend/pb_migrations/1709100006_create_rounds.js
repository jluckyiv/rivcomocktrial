/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const tournaments = app.findCollectionByNameOrId("tournaments");

    const collection = new Collection({
      type: "base",
      name: "rounds",
      fields: [
        {
          type: "number",
          name: "number",
          required: true,
        },
        {
          type: "text",
          name: "date",
          max: 100,
        },
        {
          type: "select",
          name: "type",
          required: true,
          values: ["preliminary", "elimination"],
          maxSelect: 1,
        },
        {
          type: "bool",
          name: "published",
        },
        {
          type: "relation",
          name: "tournament",
          required: true,
          collectionId: tournaments.id,
          cascadeDelete: true,
          maxSelect: 1,
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
    const collection = app.findCollectionByNameOrId("rounds");
    app.delete(collection);
  }
);
