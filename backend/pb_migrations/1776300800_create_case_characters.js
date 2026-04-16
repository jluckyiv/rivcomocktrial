/// <reference path="../pb_data/types.d.ts" />
// Case characters for each tournament's mock trial problem.
// Each case has 4 prosecution witnesses and 4 defense witnesses.
// COE enters these once per year after the problem is released (typically September).
// Required before coaches can submit rosters.
migrate(
  (app) => {
    const tournaments = app.findCollectionByNameOrId("tournaments");

    const collection = new Collection({
      type: "base",
      name: "case_characters",
      // Public read: both teams, scoring attorneys, and judges need to see characters.
      // Admin-only write: COE enters characters via pbAdmin.
      listRule: "",
      viewRule: "",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "tournament",
          collectionId: tournaments.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "side",
          values: ["prosecution", "defense"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "text",
          name: "character_name",
          required: true,
          max: 200,
        },
        {
          type: "text",
          name: "description",
          required: false,
          max: 200,
        },
        {
          type: "number",
          name: "sort_order",
          required: true,
          min: 0,
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
    const collection = app.findCollectionByNameOrId("case_characters");
    app.delete(collection);
  }
);
