_ = require("underscore")._
parseString = require("xml2js").parseString

# Define XmlImport object
exports.XmlImport = (options)-> @_options = options

exports.XmlImport.prototype.start = (data, callback)->
  throw new Error "JSON Object required" unless _.isObject data
  throw new Error "Callback must be a function" unless _.isFunction callback

  # map(data.attachments)

  callback()

exports.XmlImport.prototype.map = (xml)->
  parseString xml, (err, result)->
    console.log(result)
