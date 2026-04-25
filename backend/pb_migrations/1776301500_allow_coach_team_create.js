/// <reference path="../pb_data/types.d.ts" />
// Allow approved coaches to create teams for themselves.
// Required for the second-team registration flow where a coach
// with an existing approved account registers an additional team.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");
    // Approved coaches may create a pending team for themselves only.
    // The status constraint prevents self-approval.
    collection.createRule =
      "@request.auth.status = 'approved'"
      + " && @request.data.coach = @request.auth.id"
      + " && @request.data.status = 'pending'";
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("teams");
    collection.createRule = null;
    app.save(collection);
  }
);
