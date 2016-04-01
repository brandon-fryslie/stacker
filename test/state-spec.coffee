{Stacker} = require './helpers'

describe 'state', ->
  stacker = null

  afterEach (done) ->
    stacker.exit done
    
  it 'passes data from task to task', ->
    stacker = new Stacker 'test test2'
    stacker.wait_for /start message: test2 here, checking test data: just some passed thru test data/

  it 'handles returning non-object from task callback', ->
    stacker = new Stacker 'test-return-non-object'
    stacker.wait_for /Started all tasks!/
    .then ->
      stacker.send_cmd 'env'
      stacker.wait_for /nonobject=its a thing!/

  it 'copies state returned from callback onto existing state', ->
    stacker = new Stacker 'test-return-new-state'
    stacker.wait_for /Started all tasks!/
    .then ->
      stacker.send_cmd 'env'
      stacker.wait_for [
        /here=is some new state for ya/
      ]
