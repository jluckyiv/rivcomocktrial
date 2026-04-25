/// <reference path="../pb_data/types.d.ts" />
// One row per scored presentation within a ballot submission.
// Flat denormalization of the domain ScoredPresentation type.
// sort_order preserves presentation order on the ballot.
migrate(
  (app) => {
    const ballotSubmissions = app.findCollectionByNameOrId("ballot_submissions");
    const rosterEntries = app.findCollectionByNameOrId("roster_entries");

    const collection = new Collection({
      type: "base",
      name: "ballot_scores",
      // Admins bypass via pbAdmin (superuser).
      listRule: null,
      viewRule: null,
      createRule: "",
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "ballot",
          collectionId: ballotSubmissions.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "presentation",
          values: [
            "pretrial",
            "opening",
            "direct_examination",
            "cross_examination",
            "closing",
            "witness_examination",
            "clerk_performance",
            "bailiff_performance",
          ],
          maxSelect: 1,
          required: true,
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
          name: "student_name",
          required: true,
          max: 200,
        },
        {
          // Optional link to the roster entry for traceability.
          // Nullable because the roster may not have been submitted yet
          // (admin manual entry) or may have changed after scoring.
          type: "relation",
          name: "roster_entry",
          collectionId: rosterEntries.id,
          required: false,
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "number",
          name: "points",
          required: true,
          min: 1,
          max: 10,
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
    const collection = app.findCollectionByNameOrId("ballot_scores");
    app.delete(collection);
  }
);
