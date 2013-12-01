_ = require('underscore')._
{parseString} = require 'xml2js'
Config = require '../config'
Rest = require('sphere-node-connect').Rest
Sync = require('sphere-product-sync').Sync
Q = require('q')

# Define XmlImport object
exports.XmlImport = (options) ->
  @_options = options
  @sync = new Sync Config
  @rest = @sync._rest
  return

exports.XmlImport.prototype.process = (data, callback) ->
  throw new Error 'JSON Object required' unless _.isObject data
  throw new Error 'Callback must be a function' unless _.isFunction callback

  if data.attachments
    for k,v of data.attachments
      @transform @getAndFix(v), (data) =>
        @createOrUpdate data, callback
  else
    @returnResult false, 'No products given', callback

exports.XmlImport.prototype.returnResult = (positiveFeedback, msg, callback) ->
  d =
    message:
      status: positiveFeedback
      msg: msg
  console.log 'Error occurred: %j', d if not positiveFeedback
  callback d

exports.XmlImport.prototype.createOrUpdate = (data, callback) ->
  for p in data.products
    query = encodeURIComponent "masterData(current(masterVariant(sku=\"#{p.masterVariant.sku}\")))"
    @rest.GET "/products?where=#{query}", (error, response, body) =>
      if response.statusCode is 200
        json = JSON.parse(body)
        if json.total is 1
          p.id = json.results[0].id
          p.version = json.results[0].version
          p2 = json.results[0].masterData.staged
          p2.id = json.results[0].id
          p2.version = json.results[0].version
          diff = @sync.buildActions p, p2
          diff.update (error, response, body) =>
            if response.statusCode is 200
              if body is null
                @returnResult true, 'Nothing updated', callback
              else
                @returnResult true, 'Product updated', callback
            else
              @returnResult false, 'Problem on updating existing product.' + body, callback
        else
          @rest.POST '/products', JSON.stringify(p), (error, response, body) =>
            if response.statusCode is 201
              @returnResult true, 'New product created', callback
            else
              @returnResult false, 'Problem on creating new product.' + body, callback
      else
        @returnResult false, 'Problem on fetching existing product via sku', callback

exports.XmlImport.prototype.getAndFix = (raw) ->
  #TODO: decode base64 - make configurable for testing
  "<?xml?><root>#{raw}</root>"

exports.XmlImport.prototype.transform = (xml, callback) ->
  parseString xml, (err, result) =>
    @returnResult false, 'Error on parsing XML:' + err, callback if err
    @mapProducts result.root, callback

exports.XmlImport.prototype.mapProducts = (xmljs, callback) ->
  products = []
  variants = {} # uid -> [variant]
  images = {} # uid: variantId -> [images]

  allIds = Q.all [@products(), @productType(), @taxCategory(), @customerGroup()]
  allIds.spread (existingProducts, productTypeId, taxCategoryId, customerGroupId)=>
    id2id = {}
    for p in existingProducts
      for a in p.masterData.current.masterVariant.attributes
        if a.name is 'uid'
          id2id[a.value] = p.id
    console.log 'Number of existing products: ' + _.size(id2id)

    for k,row of xmljs.row
      v =
        id: 0
        sku: @val(row, 'uid')
      @mapCategories row, v
      @mapAttributes row, v
      @mapPrices row, v, customerGroupId
      img = @mapImages row

      if @isVariant row
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
          name: @lang n
          slug: @lang @slugify(n)
          description: @lang(@val(row, 'description', ''))
          masterVariant: v
          variants: []

        if id2id[row.uid]
          p.id = id2id[row.uid]

        @mapCategories row, p
        products.push p
        images[row.uid] = []
        images[row.uid].push img

    for p in products
      # first attribute holds uid attribute
      uid = p.masterVariant.attributes[0].value
      if variants[uid]
        p.variants = variants[uid]

    d =
      products: products,
      images: images
    callback(d)

exports.XmlImport.prototype.mapImages = (row) ->
  i = [
    url: "http://s7g1.scene7.com/is/image/DemoCommercetools/#{row.uid}",
  ]

exports.XmlImport.prototype.val = (row, name, fallback) ->
  return row[name][0] if row[name]
  fallback

exports.XmlImport.prototype.lang = (v) ->
  l =
    de: v

exports.XmlImport.prototype.slugify = (str) ->
  # trim and force lowercase
  str = str.replace(/^\s+|\s+$/g, '').toLowerCase()
  # remove invalid chars, collapse whitespace and replace by -, collapse dashes
  str.replace(/[^a-z0-9 -]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-')

exports.XmlImport.prototype.mapCategories = (row, j) ->
  j.categories = []

exports.XmlImport.prototype.mapAttributes = (row, j) ->
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
    v = @val row, n, ''
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
    v = 'YES' if @val(row, orig, '') is '1'
    d =
      name: trans
      value: v
    j.attributes.push d

exports.XmlImport.prototype.mapPrices = (row, j, customerGroupId) ->
  j.prices = []
  currency = 'EUR'
  country = 'DE'

  p =
    value:
      centAmount: @getPrice row, 'priceb2c'
      currencyCode: currency
  j.prices.push p

  p =
    value:
      centAmount: @getPrice row, 'priceb2b'
      currencyCode: currency
    customerGroup:
      typeId: 'customer-group'
      id: customerGroupId
  j.prices.push p

  return if @val(row, 'specialpriceflag', '') is '0'
  p =
    value:
      centAmount: @getPrice row, 'specialprice'
      currencyCode: currency,
    country: country
  j.prices.push p

exports.XmlImport.prototype.getPrice = (row, name) ->
  parseInt(parseFloat(@val(row, name, ''), 10) * 100)

exports.XmlImport.prototype.isVariant = (row) ->
  if row.basisUidartnr is undefined
    return false
  if row.basisUidartnr is row.uid
    return false
  true

exports.XmlImport.prototype.products = ->
  deferred = Q.defer()
  @rest.GET '/products', (error, response, body) ->
    if response.statusCode is 200
      products = JSON.parse(body).results
      deferred.resolve products
    else
      deferred.reject new Error 'Problem on fetching products'
  deferred.promise

exports.XmlImport.prototype.productType = ->
  @getFirst '/product-types'

exports.XmlImport.prototype.taxCategory = ->
  @getFirst '/tax-categories'

exports.XmlImport.prototype.customerGroup = ->
  @getFirst '/customer-groups'

exports.XmlImport.prototype.getFirst = (endpoint) ->
  deferred = Q.defer()
  @rest.GET endpoint, (error, response, body) ->
    if response.statusCode is 200
      res = JSON.parse(body).results
      if res.length > 0
        deferred.resolve res[0].id
      else
      deferred.reject new Error "There are no entries at #{endpoint}"
    else
      deferred.reject new Error "Problem on getting #{endpoint}"
  deferred.promise