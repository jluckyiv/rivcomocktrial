/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const rounds = app.findCollectionByNameOrId("rounds");
    const teams = app.findCollectionByNameOrId("teams");
    const courtrooms = app.findCollectionByNameOrId("courtrooms");

    const collection = new Collection({
      type: "base",
      name: "trials",
      fields: [
        {
          type: "relation",
          name: "round",
          required: true,
          collectionId: rounds.id,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "prosecution_team",
          required: true,
          collectionId: teams.id,
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "defense_team",
          required: true,
          collectionId: teams.id,
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "courtroom",
          required: false,
          collectionId: courtrooms.id,
          cascadeDelete: false,
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
    const collection = app.findCollectionByNameOrId("trials");
    app.delete(collection);
  }
);
