/// <reference path="../pb_data/types.d.ts" />
// Admin corrections applied on top of an immutable ballot_submission.
// Each correction targets one ballot_score and records the corrected
// points. The original ballot_scores row is never modified.
// VerifiedBallot in the domain merges original + corrections.
migrate(
  (app) => {
    const ballotSubmissions = app.findCollectionByNameOrId("ballot_submissions");
    const ballotScores = app.findCollectionByNameOrId("ballot_scores");

    const collection = new Collection({
      type: "base",
      name: "ballot_corrections",
      // Admin-only. Admins bypass via pbAdmin (superuser).
      listRule: null,
      viewRule: null,
      createRule: null,
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
          type: "relation",
          name: "original_score",
          collectionId: ballotScores.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "number",
          name: "corrected_points",
          required: true,
          min: 1,
          max: 10,
        },
        {
          type: "text",
          name: "reason",
          required: false,
          max: 500,
        },
        {
          type: "date",
          name: "corrected_at",
          required: true,
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
    const collection = app.findCollectionByNameOrId("ballot_corrections");
    app.delete(collection);
  }
);
