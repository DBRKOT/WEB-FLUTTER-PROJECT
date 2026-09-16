/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "createRule": "@request.body.role = \"client\"",
    "updateRule": "@request.auth.role = \"admin\" || (id = @request.auth.id && @request.body.role:isset = false)"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "createRule": "",
    "updateRule": "@request.auth.role = \"admin\" || id = @request.auth.id"
  }, collection)

  return app.save(collection)
})
