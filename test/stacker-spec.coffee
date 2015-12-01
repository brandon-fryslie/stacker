assert = require 'assert'

describe 'Stacker', ->
  it 'should be able to fail a test', ->
    assert.equal true, false

  it 'should be able to pass a test', ->
    assert.equal true, true
