/// <reference path="../pb_data/types.d.ts" />
// Add roster_deadline_hours to tournaments.
// Number of hours before round start time that rosters must be submitted.
// Configurable per tournament by COE. Default: 48 hours.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");

    if (!collection.fields.getByName("roster_deadline_hours")) {
      collection.fields.push(
        new Field({
          type: "number",
          name: "roster_deadline_hours",
          required: false,
          min: 0,
        })
      );
    }

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");
    collection.fields = collection.fields.filter(
      (f) => f.name !== "roster_deadline_hours"
    );
    app.save(collection);
  }
);
