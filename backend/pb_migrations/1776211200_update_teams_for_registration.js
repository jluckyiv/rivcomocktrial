/// <reference path="../pb_data/types.d.ts" />
// Add status + coach fields to teams, make tournament optional,
// and allow public creation for the registration flow.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");
    const users = app.findCollectionByNameOrId("users");

    // Add status field (pending while awaiting RCOE approval)
    collection.fields.push(
      new Field({
        type: "select",
        name: "status",
        values: ["pending", "active", "withdrawn", "rejected"],
        maxSelect: 1,
      })
    );

    // Add coach relation (the registering teacher)
    collection.fields.push(
      new Field({
        type: "relation",
        name: "coach",
        collectionId: users.id,
        maxSelect: 1,
        required: false,
      })
    );

    // tournament stays required — teams are always created with a
    // tournament by the registration hook, never by the client.

    // Admin-only for all operations; the registration hook creates
    // teams server-side using admin privileges.
    collection.createRule = null;
    collection.listRule = null;
    collection.viewRule = null;
    collection.updateRule = null;
    collection.deleteRule = null;

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");

    collection.fields = collection.fields.filter(
      (f) => !["status", "coach"].includes(f.name)
    );

    collection.createRule = null;
    collection.listRule = null;
    collection.viewRule = null;
    collection.updateRule = null;
    collection.deleteRule = null;

    app.save(collection);
  }
);
