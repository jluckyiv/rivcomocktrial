/// <reference path="../pb_data/types.d.ts" />
// Courtroom task assignments for attorneys.
// One row per task: an attorney roster entry is linked to a specific courtroom task.
// An attorney may have multiple tasks (e.g., opening + two directs + closing).
// character: which witness is being examined (for direct/cross tasks).
// sort_order: display order on the roster form.
migrate(
  (app) => {
    const rosterEntries = app.findCollectionByNameOrId("roster_entries");
    const caseCharacters = app.findCollectionByNameOrId("case_characters");

    const collection = new Collection({
      type: "base",
      name: "attorney_tasks",
      // Public read: ballot UI pre-population requires cross-team reads.
      // Coach write via chained relation.
      listRule: "",
      viewRule: "",
      createRule: "roster_entry.team.coach = @request.auth.id",
      updateRule: "roster_entry.team.coach = @request.auth.id",
      deleteRule: "roster_entry.team.coach = @request.auth.id",
      fields: [
        {
          type: "relation",
          name: "roster_entry",
          collectionId: rosterEntries.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "task_type",
          values: ["opening", "direct", "cross", "closing"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "relation",
          name: "character",
          collectionId: caseCharacters.id,
          required: false,
          cascadeDelete: false,
          maxSelect: 1,
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
    const collection = app.findCollectionByNameOrId("attorney_tasks");
    app.delete(collection);
  }
);
