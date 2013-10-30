_ = require("underscore")._
jsondiffpatch = require("jsondiffpatch")

# Define Sync object
exports.Sync = (options)-> @_options = options

exports.Sync.prototype.start = (data, callback)->
  throw new Error "JSON Object required" unless _.isObject data
  throw new Error "Callback must be a function" unless _.isFunction callback

  # data should be an existing valid JSON Product
  id = data.id

  # TODO: fetch the given product
  # product = {}

  # Diff 'em
  # diff = diff(data, product)
  callback()


exports.Sync.prototype.diff = (old_obj, new_obj)-> jsondiffpatch.diff(old_obj, new_obj)

exports.Sync.prototype.builActions = -> #noop
