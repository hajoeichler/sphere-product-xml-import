XmlImport = require("../lib/xmlimport").XmlImport

describe "XmlImport", ->
  beforeEach ->
    @xmlImport = new XmlImport("foo")

  it "should initialize", ->
    expect(@xmlImport).toBeDefined()

  it "should initialize with options", ->
    expect(@xmlImport._options).toBe "foo"


describe "XmlImport.start", ->
  beforeEach ->
    @xmlImport = new XmlImport()

  it "should throw error if no JSON object is passed", ->
    expect(@xmlImport.start).toThrow new Error("JSON Object required")

  it "should throw error if no JSON object is passed", ->
    expect(=> @xmlImport.start({})).toThrow new Error("Callback must be a function")

  it "should call the given callback", ->
    callbackExecuted = false
    callMe = ->
      callbackExecuted = true
      true
    @xmlImport.start({}, callMe)
    waitsFor(callMe, "XmlImport never completed", 10000)
    runs ->
      expect(callbackExecuted).toBe true
