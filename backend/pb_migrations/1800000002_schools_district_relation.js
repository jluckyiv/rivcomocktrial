/// <reference path="../pb_data/types.d.ts" />
// Replace schools.district (text) with a relation to the districts collection.
migrate(
  (app) => {
    const schools = app.findCollectionByNameOrId("schools");
    const districts = app.findCollectionByNameOrId("districts");

    schools.fields = schools.fields.filter((f) => f.name !== "district");

    schools.fields.push(
      new Field({
        type: "relation",
        name: "district",
        collectionId: districts.id,
        cascadeDelete: false,
        maxSelect: 1,
        required: false,
      })
    );

    app.save(schools);
  },
  (app) => {
    const schools = app.findCollectionByNameOrId("schools");
    const districts = app.findCollectionByNameOrId("districts");

    schools.fields = schools.fields.filter((f) => f.name !== "district");

    schools.fields.push(
      new Field({
        type: "text",
        name: "district",
        max: 200,
      })
    );

    app.save(schools);
  }
);
