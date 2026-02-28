/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = new Collection({
      type: "base",
      name: "courtrooms",
      fields: [
        {
          type: "text",
          name: "name",
          required: true,
          max: 100,
        },
        {
          type: "text",
          name: "location",
          max: 200,
        },
        {
          type: "autodate",
          name: "created",
          onCreate: true,
          onUpdate: false,
        },
        {
          type: "autodate",
          name: "updated",
          onCreate: true,
          onUpdate: true,
        },
      ],
    });

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("courtrooms");
    app.delete(collection);
  }
);
