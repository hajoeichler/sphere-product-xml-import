Sync = require("../lib/sync").Sync

describe "Sync", ->

  beforeEach ->
    @sync = new Sync("foo")

  it "should get data", ->
    expect(@sync.getData()).toBe "foo"