parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

parallel 'state', ->

  it 'passes data from task to task', ->
    with_stacker 'test test2', (stacker) ->
      stacker.wait_for /start message: test2 here, checking test data: just some passed thru test data/

  it 'handles returning non-object from task callback', ->
    with_stacker 'test-return-non-object', (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /nonobject=its a thing!/

  it 'copies state returned from callback onto existing state', ->
    with_stacker 'test-return-new-state', (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for [
          /here=is some new state for ya/
        ]
