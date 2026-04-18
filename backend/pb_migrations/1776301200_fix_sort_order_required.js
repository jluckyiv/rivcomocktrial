/// <reference path="../pb_data/types.d.ts" />
// PocketBase treats 0 as blank for required number fields.
// sort_order 0 is a valid first position, so remove the required flag
// from sort_order on case_characters, roster_entries, and attorney_tasks.
migrate(
  (app) => {
    for (const name of ["case_characters", "roster_entries", "attorney_tasks"]) {
      const collection = app.findCollectionByNameOrId(name);
      const field = collection.fields.getByName("sort_order");
      if (field) {
        field.required = false;
      }
      app.save(collection);
    }
  },
  (app) => {
    for (const name of ["case_characters", "attorney_tasks"]) {
      const collection = app.findCollectionByNameOrId(name);
      const field = collection.fields.getByName("sort_order");
      if (field) {
        field.required = true;
      }
      app.save(collection);
    }
    // roster_entries.sort_order was already not required — leave it
  }
);
