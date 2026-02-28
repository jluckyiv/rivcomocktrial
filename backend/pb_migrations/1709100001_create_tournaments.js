/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = new Collection({
      type: "base",
      name: "tournaments",
      fields: [
        {
          type: "text",
          name: "name",
          required: true,
          max: 200,
        },
        {
          type: "number",
          name: "year",
          required: true,
        },
        {
          type: "number",
          name: "num_preliminary_rounds",
          required: true,
        },
        {
          type: "number",
          name: "num_elimination_rounds",
          required: true,
        },
        {
          type: "select",
          name: "status",
          required: true,
          values: ["draft", "registration", "active", "completed"],
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
    const collection = app.findCollectionByNameOrId("tournaments");
    app.delete(collection);
  }
);
