/// <reference path="../pb_data/types.d.ts" />
// Withdrawal requests for teams that need to drop out mid-season.
// Coaches submit; RCOE admins approve or reject.
// The withdrawal.pb.js hook sets the team status when approved.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");

    const collection = new Collection({
      type: "base",
      name: "withdrawal_requests",
      // Coaches see only their own team's requests.
      // Admins bypass rules via pbAdmin (superuser).
      listRule: "team.coach = @request.auth.id",
      viewRule: "team.coach = @request.auth.id",
      createRule: "team.coach = @request.auth.id",
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "team",
          collectionId: teams.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "text",
          name: "reason",
          required: false,
          max: 1000,
        },
        {
          type: "select",
          name: "status",
          values: ["pending", "approved", "rejected"],
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
    const collection = app.findCollectionByNameOrId("withdrawal_requests");
    app.delete(collection);
  }
);
