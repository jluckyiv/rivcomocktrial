/// <reference path="../pb_data/types.d.ts" />
// PocketBase v0.36.x ships with a default "users" auth
// collection. Extend it with coach-specific fields.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("users");

    collection.fields.push(
      new Field({
        type: "select",
        name: "role",
        values: ["coach"],
        maxSelect: 1,
      })
    );

    collection.fields.push(
      new Field({
        type: "relation",
        name: "school",
        collectionId: app.findCollectionByNameOrId("schools").id,
        maxSelect: 1,
      })
    );

    collection.fields.push(
      new Field({
        type: "text",
        name: "team_name",
        max: 200,
      })
    );

    collection.fields.push(
      new Field({
        type: "select",
        name: "status",
        values: ["pending", "approved", "rejected"],
        maxSelect: 1,
      })
    );

    // Public create (registration), admin-only for list/view
    collection.createRule = "";
    collection.listRule = null;
    collection.viewRule = null;
    collection.updateRule = null;
    collection.deleteRule = null;

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("users");

    collection.fields = collection.fields.filter(
      (f) =>
        !["role", "school", "team_name", "status"].includes(
          f.name
        )
    );

    collection.createRule = null;
    collection.listRule = null;
    collection.viewRule = null;
    collection.updateRule = null;
    collection.deleteRule = null;

    app.save(collection);
  }
);
