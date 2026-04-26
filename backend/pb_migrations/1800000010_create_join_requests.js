/// <reference path="../pb_data/types.d.ts" />
// Join requests: a coach requests to join an existing team.
// Created by the registration hook when name+school+tournament collision
// is detected and the registrant signals join intent.
// Approved by an existing team coach or an admin.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const teams = app.findCollectionByNameOrId("teams");

    const collection = new Collection({
      type: "base",
      name: "join_requests",
      // Requester and existing coaches can list/view.
      listRule: "user = @request.auth.id || team.coaches ~ @request.auth.id",
      viewRule: "user = @request.auth.id || team.coaches ~ @request.auth.id",
      // Hook creates join requests server-side; no direct client creates.
      createRule: null,
      // Existing coaches approve/reject.
      updateRule: "team.coaches ~ @request.auth.id",
      deleteRule: null,
      fields: [
        {
          type: "relation",
          name: "user",
          collectionId: users.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
        },
        {
          type: "relation",
          name: "team",
          collectionId: teams.id,
          required: true,
          cascadeDelete: true,
          maxSelect: 1,
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
    const collection = app.findCollectionByNameOrId("join_requests");
    app.delete(collection);
  }
);
