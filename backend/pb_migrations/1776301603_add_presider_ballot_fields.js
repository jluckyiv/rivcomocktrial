/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("presider_ballots");

    collection.fields.add(
      new Field({
        type: "select",
        name: "motion_ruling",
        required: false,
        values: ["granted", "denied"],
        maxSelect: 1,
      })
    );

    collection.fields.add(
      new Field({
        type: "select",
        name: "verdict",
        required: false,
        values: ["guilty", "not_guilty"],
        maxSelect: 1,
      })
    );

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("presider_ballots");

    collection.fields.removeByName("motion_ruling");
    collection.fields.removeByName("verdict");

    app.save(collection);
  }
);
