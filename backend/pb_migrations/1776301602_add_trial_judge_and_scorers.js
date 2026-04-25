/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("trials");
    const judges = app.findCollectionByNameOrId("judges");

    const relationField = (name) =>
      new Field({
        type: "relation",
        name,
        required: false,
        collectionId: judges.id,
        cascadeDelete: false,
        maxSelect: 1,
      });

    collection.fields.add(relationField("judge"));
    collection.fields.add(relationField("scorer_1"));
    collection.fields.add(relationField("scorer_2"));
    collection.fields.add(relationField("scorer_3"));
    collection.fields.add(relationField("scorer_4"));
    collection.fields.add(relationField("scorer_5"));

    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("trials");

    collection.fields.removeByName("judge");
    collection.fields.removeByName("scorer_1");
    collection.fields.removeByName("scorer_2");
    collection.fields.removeByName("scorer_3");
    collection.fields.removeByName("scorer_4");
    collection.fields.removeByName("scorer_5");

    app.save(collection);
  }
);
