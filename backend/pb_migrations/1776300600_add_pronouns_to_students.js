/// <reference path="../pb_data/types.d.ts" />
// Add pronouns field to students.
// Used on rosters so opposing attorneys know how to refer to witnesses in court.
// Stored as plain text: "he/him", "she/her", "they/them", or free text.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("students");

    if (!collection.fields.getByName("pronouns")) {
      collection.fields.push(
        new Field({
          type: "text",
          name: "pronouns",
          required: false,
          max: 100,
        })
      );
    }

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("students");
    collection.fields = collection.fields.filter(
      (f) => f.name !== "pronouns"
    );
    app.save(collection);
  }
);
