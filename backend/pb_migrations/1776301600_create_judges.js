/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = new Collection({
      type: "base",
      name: "judges",
      fields: [
        {
          type: "text",
          name: "name",
          required: true,
          max: 200,
        },
        {
          type: "email",
          name: "email",
          required: false,
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
    const collection = app.findCollectionByNameOrId("judges");
    app.delete(collection);
  }
);
