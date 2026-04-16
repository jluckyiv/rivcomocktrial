/// <reference path="../pb_data/types.d.ts" />
// One row per student per round per side per team.
// entry_type: active = competing, substitute = pre-declared sub, non_active = observer only.
// role: prosecution teams provide the clerk; defense teams provide the bailiff.
// character: only for witness roles — links to a case_characters record.
// sort_order: for witnesses, the order they will be called.
migrate(
  (app) => {
    const teams = app.findCollectionByNameOrId("teams");
    const rounds = app.findCollectionByNameOrId("rounds");
    const students = app.findCollectionByNameOrId("students");
    const caseCharacters = app.findCollectionByNameOrId("case_characters");

    const collection = new Collection({
      type: "base",
      name: "roster_entries",
      // Public read: both teams in a pairing and scoring attorneys need access.
      // TODO: tighten to trial participants when scoring workflow is built.
      listRule: "",
      viewRule: "",
      createRule: "team.coach = @request.auth.id",
      updateRule: "team.coach = @request.auth.id",
      deleteRule: "team.coach = @request.auth.id",
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
          type: "relation",
          name: "student",
          collectionId: students.id,
          required: false,
          cascadeDelete: false,
          maxSelect: 1,
        },
        {
          type: "select",
          name: "entry_type",
          values: ["active", "substitute", "non_active"],
          maxSelect: 1,
          required: true,
        },
        {
          type: "select",
          name: "role",
          values: [
            "pretrial_attorney",
            "trial_attorney",
            "witness",
            "clerk",
            "bailiff",
            "artist",
            "journalist",
          ],
          maxSelect: 1,
          required: false,
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
          required: false,
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
    const collection = app.findCollectionByNameOrId("roster_entries");
    app.delete(collection);
  }
);
