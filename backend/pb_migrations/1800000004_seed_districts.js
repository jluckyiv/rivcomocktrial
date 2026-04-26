/// <reference path="../pb_data/types.d.ts" />
// Seed the 19 Riverside County districts if the collection is empty.
// Down migration is a no-op — never auto-delete reference data.
migrate(
  (app) => {
    const existing = app.findRecordsByFilter("districts", "id != ''", "", 1, 0);
    if (existing.length > 0) return;

    const collection = app.findCollectionByNameOrId("districts");

    const names = [
      "Alvord Unified School District",
      "Banning Unified School District",
      "Beaumont Unified School District",
      "Coachella Valley Unified School District",
      "Corona-Norco Unified School District",
      "Desert Sands Unified School District",
      "Diocese of San Bernardino",
      "Hemet Unified School District",
      "Jurupa Unified School District",
      "Lake Elsinore Unified School District",
      "Moreno Valley Unified School District",
      "Murrieta Valley Unified School District",
      "Palm Springs Unified School District",
      "Palo Verde Unified School District",
      "Perris Union High School District",
      "Riverside Unified School District",
      "San Jacinto Unified School District",
      "Temecula Valley Unified School District",
      "Val Verde Unified School District",
    ];

    for (const name of names) {
      const record = new Record(collection);
      record.set("name", name);
      app.save(record);
    }
  },
  (_app) => {}
);
