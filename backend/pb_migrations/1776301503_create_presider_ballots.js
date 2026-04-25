/// <reference path="../pb_data/types.d.ts" />
// Presider ballot: sealed side selection used as tiebreaker only.
// One per trial, submitted by the presiding judge via a presider token.
// Kept separate from ballot_submissions so it is never accidentally
// included in Court Total calculations.
migrate(
  (app) => {
    const scorerTokens = app.findCollectionByNameOrId("scorer_tokens");
    const trials = app.findCollectionByNameOrId("trials");

    const collection = new Collection({
      type: "base",
      name: "presider_ballots",
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
          name: "winner_side",
          values: ["prosecution", "defense"],
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
    const collection = app.findCollectionByNameOrId("presider_ballots");
    app.delete(collection);
  }
);
