fs = require('fs')
XmlImport = require("../lib/xmlimport").XmlImport
Config = require('../config').config
Sync = require("sphere-product-sync").Sync
Rest = require("sphere-node-connect").Rest

describe "Integration", ->
  beforeEach ->
    @xmlImport = new XmlImport()
    @sync = new Sync Config
    rest = new Rest Config
    rest.GET "/products", (error, response, body)->
      expect(response.statusCode).toBe 200
      for p in JSON.parse(body).results
        rest.DELETE "/products/#{p.id}?version=#{p.version}", (error, response, body)->
          expect(response.statusCode.toString()).toMatch /[24]00/

  it 'process', (done)->
    fs.readFile 'src/spec/oneProduct.xml', 'utf8', (err, content)=>
      expect(err).toBeUndefined
      data =
        attachments:
          oneProduct: content
      @xmlImport.process data, (cb)->
        console.log("PROCESS %j", cb)
        done()