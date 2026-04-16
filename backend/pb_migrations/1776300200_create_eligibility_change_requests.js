/// <reference path="../pb_data/types.d.ts" />
// Post-lock change requests for the eligibility list.
// Coaches submit; RCOE admins approve or reject.
// The eligibility.pb.js hook applies the change when approved.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");

    const collection = new Collection({
      type: "base",
      name: "eligibility_change_requests",
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
          name: "student_name",
          required: true,
          max: 200,
        },
        {
          type: "select",
          name: "change_type",
          values: ["add", "remove"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "text",
          name: "notes",
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
    const collection = app.findCollectionByNameOrId(
      "eligibility_change_requests"
    );
    app.delete(collection);
  }
);
