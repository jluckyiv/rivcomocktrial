/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("rounds");

    collection.fields.add(
      new Field({
        type: "select",
        name: "status",
        required: true,
        values: ["upcoming", "open", "locked"],
        maxSelect: 1,
      })
    );

    collection.fields.add(
      new Field({
        type: "number",
        name: "ranking_min",
        required: false,
        nullable: true,
        min: 1,
        max: 5,
      })
    );

    collection.fields.add(
      new Field({
        type: "number",
        name: "ranking_max",
        required: false,
        nullable: true,
        min: 1,
        max: 5,
      })
    );

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("rounds");

    collection.fields.removeByName("status");
    collection.fields.removeByName("ranking_min");
    collection.fields.removeByName("ranking_max");

    app.save(collection);
  }
);
