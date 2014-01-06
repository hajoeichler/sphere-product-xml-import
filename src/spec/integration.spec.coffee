fs = require 'fs'
xmlHelpers = require '../lib/xmlhelpers'
XmlImport = require '../lib/xmlimport'
Config = require '../config'
Rest = require('sphere-node-connect').Rest
Q = require 'q'

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 20000

describe '#process', ->
  beforeEach (done) ->
    deleteProduct = (rest, p) ->
      deffered = Q.defer()
      unpublish =
        id: p.id
        version: p.version
        actions: [
          action: 'unpublish'
        ]
      rest.POST "/products/#{p.id}", JSON.stringify(unpublish), (error, response, body) ->
        v = p.version
        if response.statusCode is 200
          v = v + 1
        rest.DELETE "/products/#{p.id}?version=#{v}", (error, response, body) ->
          if response.statusCode is 200
            deffered.resolve body
          else
            deffered.reject body
      deffered.promise

    @xmlImport = new XmlImport Config
    @rest = @xmlImport.rest
    @rest.GET '/products', (error, response, body) =>
      expect(response.statusCode).toBe 200
      products = JSON.parse(body).results
      if products.length is 0
        done()
      deletions = []
      for p in products
        deletions.push deleteProduct(@rest, p)
      Q.all(deletions).then () ->
        done()
      .fail (msg) ->
        console.log msg
        expect(true).toBe false
        done()

  it 'create new product and update afterwards without differences', (done) ->
    fs.readFile 'src/spec/oneProduct.xml', 'utf8', (err, content) =>
      expect(err).toBeUndefined
      data =
        attachments:
          oneProduct: content
      @xmlImport.process data, (result) =>
        expect(result.status).toBe true
        expect(result.message).toBe 'New product created'
        @xmlImport.process data, (result) =>
          expect(result.status).toBe true
          expect(result.message).toBe 'Nothing updated'
          @rest.GET '/products', (error, response, body) ->
            expect(response.statusCode).toBe 200
            products = JSON.parse(body).results
            expect(products[0].masterData.staged.name.de).toBe 'Short Name'
            expect(products[0].masterData.staged.slug.de).toBe 'short-name'
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
        expect(result.status).toBe true
        expect(result.message).toBe 'New product created'
        @xmlImport.process d2, (result) =>
          expect(result.status).toBe true
          expect(result.message).toBe 'Product updated'
          @rest.GET '/products', (error, response, body) ->
            expect(response.statusCode).toBe 200
            products = JSON.parse(body).results
            expect(products[0].version).toBe 3
            expect(products[0].masterData.staged.name.de).toBe 'Replaced Name'
            expect(products[0].masterData.staged.slug.de).toBe 'replaced-name'
            done()