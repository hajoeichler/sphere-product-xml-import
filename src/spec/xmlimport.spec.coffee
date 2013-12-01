Config = require '../config'
XmlImport = require('../lib/xmlimport').XmlImport

describe 'XmlImport', ->
  beforeEach ->
    @xmlImport = new XmlImport('foo')

  it 'should initialize', ->
    expect(@xmlImport).toBeDefined()

  it 'should initialize with options', ->
    expect(@xmlImport._options).toBe 'foo'


describe 'XmlImport.process', ->
  beforeEach ->
    @xmlImport = new XmlImport()

  it 'should throw error if no JSON object is passed', ->
    expect(@xmlImport.process).toThrow new Error('JSON Object required')

  it 'should throw error if no JSON object is passed', ->
    expect(=> @xmlImport.process({})).toThrow new Error('Callback must be a function')

  it 'should call the given callback and return messge', (done) ->
    @xmlImport.process {}, (data)->
      expect(data.message.status).toBe false
      expect(data.message.msg).toBe 'No products given'
      done()

describe 'XmlImport.helper', ->
  beforeEach ->
    @xmlImport = new XmlImport()

  it 'isVariant for product', ->
    row =
      uid: 123
    expect(@xmlImport.isVariant(row)).toBe false

  it 'isVariant for variant', ->
    row =
      uid: 123
      basisUidartnr: 'abc'
    expect(@xmlImport.isVariant(row)).toBe true

describe 'XmlImport.transform', ->
  beforeEach ->
    @xmlImport = new XmlImport Config

  it 'single attachment - product plus variant', (done) ->
    rawXml = '
<row>
  <uid>123</uid>
  <name>Some long name with "chars"</name>
  <descriptionVariant>Short name</descriptionVariant>
  <codeMaterial>42</codeMaterial>
  <descriptionMaterial>Nice material</descriptionMaterial>
  <codecolorname>7</codecolorname>
  <descriptionColorname>Olive</descriptionColorname>
  <codeFilterColor>99</codeFilterColor>
  <descriptionFilterColor>Black</descriptionFilterColor>
  <codeStyle>1</codeStyle>
  <descriptionFilterStyle>Cool</descriptionFilterStyle>
  <codeFabrication>2</codeFabrication>
  <descriptionFabrication>hand made</descriptionFabrication>
  <priceb2c>99.99</priceb2c>
  <priceb2b>75.000000</priceb2b>
  <codeTaxGroup>1</codeTaxGroup>
  <descriptionTaxGroup>19.000</descriptionTaxGroup>
  <ean>123</ean>
  <bulkygoods>1</bulkygoods>
  <specialpriceflag>1</specialpriceflag>
  <specialprice>89.99</specialprice>
</row>
<row>
  <uid>234</uid>
  <basisUidartnr>123</basisUidartnr>
  <descriptionVariant>Short name</descriptionVariant>
  <codeMaterial>42</codeMaterial>
  <descriptionMaterial>Nice material</descriptionMaterial>
  <codecolorname>7</codecolorname>
  <descriptionColorname>Olive</descriptionColorname>
  <codeFilterColor>55</codeFilterColor>
  <descriptionFilterColor>Green</descriptionFilterColor>
  <codeStyle>1</codeStyle>
  <descriptionFilterStyle>Cool</descriptionFilterStyle>
  <codeFabrication>2</codeFabrication>
  <descriptionFabrication>hand made</descriptionFabrication>
  <priceb2c>99.99</priceb2c>
  <priceb2b>75.000000</priceb2b>
  <codeTaxGroup>1</codeTaxGroup>
  <descriptionTaxGroup>19.000</descriptionTaxGroup>
  <ean>123</ean>
  <bulkygoods>0</bulkygoods>
  <specialpriceflag>0</specialpriceflag>
  <specialprice>0.000</specialprice>
</row>'

    @xmlImport.transform @xmlImport.getAndFix(rawXml), (output) ->
      console.log(output)
      expect(output.products.length).toBe 1
      p = output.products[0]
      expect(p.name.de).toBe 'Short name'
      expect(p.slug.de).toBe 'short-name'
      expect(p.productType.typeId).toBe 'product-type'
      expect(p.productType.id.length).toBe 36
      expect(p.taxCategory.typeId).toBe 'tax-category'
      expect(p.taxCategory.id.length).toBe 36

      expect(p.categories.length).toBe 0

      expect(p.masterVariant).toBeDefined
      m = p.masterVariant
      expect(m.id).toBe 1
      expect(m.attributes).toBeDefined
      expect(m.prices.length).toBe 3

      expect(p.variants.length).toBe 1
      v = p.variants[0]
      expect(v.id).toBe 2
      expect(v.attributes).toBeDefined
      expect(v.prices.length).toBe 2
      done()
