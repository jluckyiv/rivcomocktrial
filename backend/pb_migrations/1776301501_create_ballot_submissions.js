/// <reference path="../pb_data/types.d.ts" />
// One ballot submission per scorer token (unique constraint enforced
// by the ballot_guard hook). Immutable after creation — the original
// submission is always preserved for audit purposes.
// ballot_corrections records corrections on top of the original.
migrate(
  (app) => {
    const scorerTokens = app.findCollectionByNameOrId("scorer_tokens");
    const trials = app.findCollectionByNameOrId("trials");

    const collection = new Collection({
      type: "base",
      name: "ballot_submissions",
      // Scorers cannot list/view their own submissions after submit.
      // Admins bypass via pbAdmin (superuser).
      listRule: null,
      viewRule: null,
      createRule: "",
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "scorer_token",
          collectionId: scorerTokens.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "trial",
          collectionId: trials.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "status",
          values: ["submitted", "verified", "corrected"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "date",
          name: "submitted_at",
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
    const collection = app.findCollectionByNameOrId("ballot_submissions");
    app.delete(collection);
  }
);
