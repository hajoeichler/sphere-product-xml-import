Sync = require("../lib/sync").Sync

describe "Sync", ->
  beforeEach ->
    @sync = new Sync("foo")

  it "should initialize", ->
    expect(@sync).toBeDefined()

  it "should initialize with options", ->
    expect(@sync._options).toBe "foo"


describe "Sync.start", ->
  beforeEach ->
    @sync = new Sync()

  it "should throw error if no JSON object is passed", ->
    expect(@sync.start).toThrow new Error("JSON Object required")

  it "should throw error if no JSON object is passed", ->
    expect(=> @sync.start({})).toThrow new Error("Callback must be a function")

  it "should call the given callback", ->
    callbackExecuted = false
    callMe = ->
      callbackExecuted = true
      true
    @sync.start({}, callMe)
    waitsFor(callMe, "Sync never completed", 10000)
    runs ->
      expect(callbackExecuted).toBe true