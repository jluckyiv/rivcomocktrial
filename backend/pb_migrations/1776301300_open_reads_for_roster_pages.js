/// <reference path="../pb_data/types.d.ts" />
// Open read access on rounds, trials, and students so coaches
// can load roster data via the public PB client.
// roster_entries, roster_submissions, case_characters already
// have open reads from earlier migrations.
migrate(
  (app) => {
    for (const name of ["rounds", "trials", "students"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.listRule = "";
      collection.viewRule = "";
      app.save(collection);
    }
  },
  (app) => {
    for (const name of ["rounds", "trials", "students"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.listRule = null;
      collection.viewRule = null;
      app.save(collection);
    }
  }
);
