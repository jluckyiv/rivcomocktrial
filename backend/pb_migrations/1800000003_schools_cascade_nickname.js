/// <reference path="../pb_data/types.d.ts" />
// Add cascadeDelete to schools.district relation and add optional nickname field.
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
        cascadeDelete: true,
        maxSelect: 1,
        required: false,
      })
    );

    schools.fields.push(
      new Field({
        type: "text",
        name: "nickname",
        max: 100,
        required: false,
      })
    );

    app.save(schools);
  },
  (app) => {
    const schools = app.findCollectionByNameOrId("schools");
    const districts = app.findCollectionByNameOrId("districts");

    schools.fields = schools.fields.filter(
      (f) => !["district", "nickname"].includes(f.name)
    );
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
  }
);
