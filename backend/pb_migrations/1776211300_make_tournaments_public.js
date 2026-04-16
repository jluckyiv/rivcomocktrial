/// <reference path="../pb_data/types.d.ts" />
// Allow unauthenticated users to read tournaments so the
// registration form can display the current tournament name
// and show "Registration is not currently open" when no
// tournament is in registration status.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");

    collection.listRule = "";
    collection.viewRule = "";

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");

    collection.listRule = null;
    collection.viewRule = null;

    app.save(collection);
  }
);
