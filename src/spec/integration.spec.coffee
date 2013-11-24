fs = require('fs')
XmlImport = require("../lib/xmlimport").XmlImport
Config = require('../config').config
Sync = require("sphere-product-sync").Sync
Rest = require("sphere-node-connect").Rest
OAuth2 = require("sphere-node-connect").OAuth2
Q = require("q")

describe "Integration", ->
  beforeEach ->
    @xmlImport = new XmlImport()
    @sync = new Sync Config

  it "round trip", (done)->
    xmlImport = @xmlImport
    sync = @sync
    fs.readFile 'src/spec/foo.xml', 'utf8', (err,data)->
      expect(err).toBeUndefined
      xmlImport.transform xmlImport.getAndFix(data), (data)->
        expect(data.message).toBeDefined
        expect(data.message.name.de).toBe "Bodenvase"
        data.message.id = "123"
        sync.start data.message, (cb)->
          console.log("SYNC %j", cb)
          if cb.status == false
            rest = new Rest Config
            rest.POST "/products", JSON.stringify(data.message), (error, response, body)->
              console.log("BODY %j", body)
              done()
    