/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3414089001")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.role = \"admin\" || @request.auth.role = \"manager\" || user = @request.auth.id",
    "updateRule": "@request.auth.role = \"admin\" || @request.auth.role = \"manager\" || user = @request.auth.id",
    "viewRule": "@request.auth.role = \"admin\" || @request.auth.role = \"manager\" || user = @request.auth.id"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3414089001")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.role = \"admin\" || user = @request.auth.id",
    "updateRule": "@request.auth.role = \"admin\" || user = @request.auth.id",
    "viewRule": "@request.auth.role = \"admin\" || user = @request.auth.id"
  }, collection)

  return app.save(collection)
})
