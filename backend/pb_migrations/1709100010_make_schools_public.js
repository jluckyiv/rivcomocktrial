/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("schools");
    collection.listRule = "";
    collection.viewRule = "";
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("schools");
    collection.listRule = null;
    collection.viewRule = null;
    app.save(collection);
  }
);
