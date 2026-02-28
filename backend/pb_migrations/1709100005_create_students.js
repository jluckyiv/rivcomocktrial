/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const schools = app.findCollectionByNameOrId("schools");

    const collection = new Collection({
      type: "base",
      name: "students",
      fields: [
        {
          type: "text",
          name: "name",
          required: true,
          max: 200,
        },
        {
          type: "relation",
          name: "school",
          required: true,
          collectionId: schools.id,
          cascadeDelete: false,
          maxSelect: 1,
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
    const collection = app.findCollectionByNameOrId("students");
    app.delete(collection);
  }
);
