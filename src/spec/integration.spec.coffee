fs = require('fs')
XmlImport = require("../lib/xmlimport").XmlImport
Config = require '../config'
Rest = require('sphere-node-connect').Rest

describe '#process', ->
  beforeEach (done) ->
    @xmlImport = new XmlImport Config
    @rest = @xmlImport.rest
    @rest.GET '/products', (error, response, body) =>
      expect(response.statusCode).toBe 200
      products = JSON.parse(body).results
      if products.length is 0
        done()
      for p in products
        @rest.DELETE "/products/#{p.id}?version=#{p.version}", (error, response, body) =>
          expect(response.statusCode.toString()).toMatch /[24]00/
          done()

  it 'create new product and update afterwards without differences', (done) ->
    fs.readFile 'src/spec/oneProduct.xml', 'utf8', (err, content) =>
      expect(err).toBeUndefined
      data =
        attachments:
          oneProduct: content
      @xmlImport.process data, (result) =>
        expect(result.message.status).toBe true
        expect(result.message.msg).toBe 'New product created'
        @xmlImport.process data, (result) =>
          expect(result.message.status).toBe true
          expect(result.message.msg).toBe 'Nothing updated'
          @rest.GET '/products', (error, response, body) =>
            expect(response.statusCode).toBe 200
            products = JSON.parse(body).results
            expect(products[0].version).toBe 1
            done()

  it 'create new product, change name and update afterwards', (done) ->
    fs.readFile 'src/spec/oneProduct.xml', 'utf8', (err, content) =>
      expect(err).toBeUndefined
      d =
        attachments:
          oneProduct: content
      d2 =
        attachments:
          oneProduct: content.replace 'Short', 'Replaced'
      @xmlImport.process d, (result) =>
        expect(result.message.status).toBe true
        expect(result.message.msg).toBe 'New product created'
        @xmlImport.process d2, (result) =>
          expect(result.message.status).toBe true
          expect(result.message.msg).toBe 'Product updated'
          @rest.GET '/products', (error, response, body) =>
            expect(response.statusCode).toBe 200
            products = JSON.parse(body).results
            expect(products[0].version).toBe 3
            done()