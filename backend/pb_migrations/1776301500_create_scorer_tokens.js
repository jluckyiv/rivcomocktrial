/// <reference path="../pb_data/types.d.ts" />
// Scorer tokens are the auth mechanism for ballot submission.
// Admin generates one token per scorer slot per trial.
// The token is embedded in a URL (/ballot/{token}) distributed
// as a QR code at check-in. Single-use: status goes active → used
// on submission. Presider tokens are separate from scorer tokens.
migrate(
  (app) => {
    const trials = app.findCollectionByNameOrId("trials");

    const collection = new Collection({
      type: "base",
      name: "scorer_tokens",
      // Scorers look up their own token by value.
      // Admins bypass via pbAdmin (superuser).
      listRule: "token = @request.query.token",
      viewRule: "token = @request.query.token",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "trial",
          collectionId: trials.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "text",
          name: "token",
          required: true,
          max: 100,
        },
        {
          type: "text",
          name: "scorer_name",
          required: false,
          max: 200,
        },
        {
          type: "select",
          name: "scorer_role",
          values: ["scorer", "presider"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "select",
          name: "status",
          values: ["active", "used", "revoked"],
          maxSelect: 1,
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
    const collection = app.findCollectionByNameOrId("scorer_tokens");
    app.delete(collection);
  }
);
