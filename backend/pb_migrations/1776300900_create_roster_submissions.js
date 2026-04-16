/// <reference path="../pb_data/types.d.ts" />
// Tracks whether a coach has formally submitted a roster for a given
// team/round/side combination.
// submitted_at null = draft; non-null = submitted.
// One record per (team, round, side). Created when coach first saves
// a roster; updated when they submit.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");
    const rounds = app.findCollectionByNameOrId("rounds");

    const collection = new Collection({
      type: "base",
      name: "roster_submissions",
      // Public read: compliance dashboard needs cross-team visibility.
      // Coach write: only for their own team.
      listRule: "",
      viewRule: "",
      createRule: "team.coach = @request.auth.id",
      updateRule: "team.coach = @request.auth.id",
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
          type: "relation",
          name: "round",
          collectionId: rounds.id,
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
          type: "date",
          name: "submitted_at",
          required: false,
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
    const collection = app.findCollectionByNameOrId("roster_submissions");
    app.delete(collection);
  }
);
