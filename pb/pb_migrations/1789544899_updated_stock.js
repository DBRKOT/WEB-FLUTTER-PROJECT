/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2154883211")

  // update field
  collection.fields.addAt(2, new Field({
    "help": "",
    "hidden": false,
    "id": "number2683508278",
    "max": 100000,
    "min": 0,
    "name": "quantity",
    "onlyInt": true,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2154883211")

  // update field
  collection.fields.addAt(2, new Field({
    "help": "",
    "hidden": false,
    "id": "number2683508278",
    "max": 100000,
    "min": 0,
    "name": "quantity",
    "onlyInt": true,
    "presentable": false,
    "required": true,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
})
