fs = require('fs')
XmlImport = require("../lib/xmlimport").XmlImport
Config = require('../config').config
Sync = require("sphere-product-sync").Sync
Rest = require("sphere-node-connect").Rest

describe "Integration", ->
  beforeEach ->
    @xmlImport = new XmlImport()
    @sync = new Sync Config

  it 'process', (done)->
    fs.readFile 'src/spec/oneProduct.xml', 'utf8', (err, content)=>
      expect(err).toBeUndefined
      data =
        attachments:
          oneProduct: content
      @xmlImport.process data, (cb)->
        console.log("PROCESS %j", cb)
        done()