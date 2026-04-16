/// <reference path="../pb_data/types.d.ts" />
// The original create_users migration was edited after it ran on
// some databases, so school, team_name, and status were never
// added to those instances. This migration adds them idempotently.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("users");
    const schools = app.findCollectionByNameOrId("schools");

    if (!collection.fields.getByName("school")) {
      collection.fields.push(
        new Field({
          type: "relation",
          name: "school",
          collectionId: schools.id,
          maxSelect: 1,
          required: false,
        })
      );
    }

    if (!collection.fields.getByName("team_name")) {
      collection.fields.push(
        new Field({
          type: "text",
          name: "team_name",
          max: 200,
          required: false,
        })
      );
    }

    if (!collection.fields.getByName("status")) {
      collection.fields.push(
        new Field({
          type: "select",
          name: "status",
          values: ["pending", "approved", "rejected"],
          maxSelect: 1,
          required: false,
        })
      );
    }

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("users");

    collection.fields = collection.fields.filter(
      (f) => !["school", "team_name", "status"].includes(f.name)
    );

    app.save(collection);
  }
);
