/// <reference path="../pb_data/types.d.ts" />
// Add eligibility_locked_at datetime to tournaments.
// Set by RCOE when the eligibility list deadline passes.
// Null = open for edits; non-null = locked (read-only for coaches).
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");

    if (!collection.fields.getByName("eligibility_locked_at")) {
      collection.fields.push(
        new Field({
          type: "date",
          name: "eligibility_locked_at",
          required: false,
        })
      );
    }

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("tournaments");

    collection.fields = collection.fields.filter(
      (f) => f.name !== "eligibility_locked_at"
    );

    app.save(collection);
  }
);
