_ = require('underscore')._
{parseString} = require 'xml2js'
Config = require('../config').config
Rest = require('sphere-node-connect').Rest
Q = require('q')

# Define XmlImport object
exports.XmlImport = (options)->
  @_options = options
  @rest = new Rest Config
  return

exports.XmlImport.prototype.process = (data, callback)->
  throw new Error 'JSON Object required' unless _.isObject data
  throw new Error 'Callback must be a function' unless _.isFunction callback

  if data.attachments
    for k,v of data.attachments
      @transform(@getAndFix(v), callback)
  else
    callback({})

exports.XmlImport.prototype.getAndFix = (raw)->
  #TODO: decode base64 - make configurable for testing
  "<?xml?><root>#{raw}</root>"

exports.XmlImport.prototype.transform = (xml, callback)->
  parseString xml, (err, result)=>
    console.log('Error on parsing XML:' + err) if err
    @mapProducts(result.root, callback)

exports.XmlImport.prototype.mapProducts = (xmljs, callback)->
  products = []
  variants = {} # uid -> [variant]
  images = {} # uid: variantId -> [images]
  varianId = 0

  allIds = Q.all [@productType(), @taxCategory(), @customerGroup()]
  allIds.spread (productTypeId, taxCategoryId, customerGroupId)=>
    for k,row of xmljs.row
      v =
        id: 0
      @mapCategories(row, v)
      @mapAttributes(row, v)
      @mapPrices(row, v, customerGroupId)
      img = @mapImages(row)

      if @isVariant(row)
        parentId = row.basisUidartnr
        variants[parentId] = [] if not variants[parentId]
        v.id = variants[parentId].length + 2
        variants[parentId].push v
        images[parentId].push img

      else
        v.id = 1
        n = @val(row, 'descriptionVariant', @val(row, 'name'))
        p =
          productType:
            typeId: 'product-type'
            id: productTypeId
          taxCategory:
            typeId: 'tax-category'
            id: taxCategoryId
          name: @lang(n)
          slug: @lang(@slugify(n))
          description: @lang(@val(row, 'description', ''))
          masterVariant: v
          variants: []

        @mapCategories(row, p)
        products.push p
        images[row.uid] = []
        images[row.uid].push img

    for p in products
      # first attribute holds uid attribute
      uid = p.masterVariant.attributes[0].value
      if variants[uid]
        p.variants = variants[uid]
      data =
        message: p
      callback(data)

exports.XmlImport.prototype.mapImages = (row)->
  i = [
    url: "http://s7g1.scene7.com/is/image/DemoCommercetools/#{row.uid}",
  ]

exports.XmlImport.prototype.val = (row, name, fallback)->
  return row[name][0] if row[name]
  fallback

exports.XmlImport.prototype.lang = (v)->
  l =
    de: v

exports.XmlImport.prototype.slugify = (str)->
  # trim and force lowercase
  str = str.replace(/^\s+|\s+$/g, '').toLowerCase()
  # remove invalid chars, collapse whitespace and replace by -, collapse dashes
  str.replace(/[^a-z0-9 -]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-')

exports.XmlImport.prototype.mapCategories = (row, j)->
  j.categories = []

exports.XmlImport.prototype.mapAttributes = (row, j)->
  j.attributes = []
  attribs =
    uid: ''
    size: ''
    codeMaterial: ''
    descriptionMaterial: ''
    codecolorname: 'codeColorname'
    descriptionColorname: ''
    codeFilterColor: ''
    descriptionFilterColor: ''
    codeStyle: ''
    descriptionFilterStyle: ''
    codeFabrication: ''
    descriptionFabrication: ''
    CodeSerie: 'codeSerie'
    descriptionSerie: ''
# TODO    codeCareinstruction: ''
# TODO    descriptionCareinstruction: ''
    Theme: 'theme'
    ean: ''

  for orig, trans of attribs
    trans = orig unless trans.length > 0
    v = @val(row, orig, '')
    continue unless v.length > 0
    d =
      name: trans
      value: v
    j.attributes.push d

  numbers = [ 'hight', 'length', 'wide' ]
  for n in numbers
    v = @val(row, n, '')
    continue unless v.length > 0
    d =
      name: n
      value: parseInt v, 10
    j.attributes.push d

  enums =
    bulkygoods: ''
    specialpriceflag: 'salesprice'
# TODO    discountable: 'discountable'
    Highlight: 'highlighted'

  for orig,trans of enums
    trans = orig unless trans.length > 0
    v = 'NO'
    v = 'YES' if @val(row, orig, '') == '1'
    d =
      name: trans
      value: v
    j.attributes.push d

exports.XmlImport.prototype.mapPrices = (row, j, customerGroupId)->
  j.prices = []
  currency = 'EUR'
  country = 'DE'

  p =
    value:
      centAmount: parseInt @val(row, 'priceb2c', ''), 10
      currencyCode: currency
  j.prices.push p

  p =
    value:
      centAmount: parseInt @val(row, 'priceb2b', ''), 10
      currencyCode: currency
    customerGroup:
      typeId: 'customer-group'
      id: customerGroupId
  j.prices.push p

  return if @val(row, 'specialpriceflag', '') is '0'
  p =
    value:
      centAmount: parseInt @val(row, 'specialprice', ''), 10
      currencyCode: currency
    country: country
  j.prices.push p

exports.XmlImport.prototype.isVariant = (row)->
  if row.basisUidartnr is undefined
    return false
  if row.basisUidartnr == row.uid
    return false
  true

exports.XmlImport.prototype.productType = ->
  deferred = Q.defer()
  @rest.GET "/product-types", (error, response, body)->
    #console.log("PT: %j", body)
    id = JSON.parse(body).results[0].id
    deferred.resolve id
  deferred.promise

exports.XmlImport.prototype.taxCategory = ->
  deferred = Q.defer()
  @rest.GET "/tax-categories", (error, response, body)->
    #console.log("TC: %j", body)
    id = JSON.parse(body).results[0].id
    deferred.resolve id
  deferred.promise

exports.XmlImport.prototype.customerGroup = ->
  deferred = Q.defer()
  @rest.GET "/customer-groups", (error, response, body)->
    id = JSON.parse(body).results[0].id
    #console.log("CG: %j", body)
    deferred.resolve id
  deferred.promise
