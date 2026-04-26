/// <reference path="../pb_data/types.d.ts" />
// Add `is_primary_contact` to `_superusers` so one admin can be
// designated as the public contact email shown on registration pages.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("_superusers");

    if (!collection.fields.getByName("is_primary_contact")) {
      collection.fields.push(
        new Field({
          type: "bool",
          name: "is_primary_contact",
          required: false,
        })
      );
    }

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("_superusers");
    collection.fields = collection.fields.filter(
      (f) => f.name !== "is_primary_contact"
    );
    app.save(collection);
  }
);
