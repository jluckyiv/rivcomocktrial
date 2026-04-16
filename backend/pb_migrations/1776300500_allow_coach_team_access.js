/// <reference path="../pb_data/types.d.ts" />
// Allow coaches to list and view their own team.
// Required for the /team/manage page which uses the coach token (admin: false).
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");
    collection.listRule = "coach = @request.auth.id";
    collection.viewRule = "coach = @request.auth.id";
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");
    collection.listRule = null;
    collection.viewRule = null;
    app.save(collection);
  }
);
