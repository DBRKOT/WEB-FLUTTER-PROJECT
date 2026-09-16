/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "viewRule": "@request.auth.role = \"admin\" || @request.auth.role = \"manager\" || id = @request.auth.id"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "viewRule": "@request.auth.role = \"admin\" || id = @request.auth.id"
  }, collection)

  return app.save(collection)
})
