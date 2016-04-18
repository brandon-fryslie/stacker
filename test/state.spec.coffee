parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

test_task_config = """
  module.exports = (state) ->
    name: 'Test'
    command: 'echo Started Server on 127.0.0.1:8080 && tail -f /dev/null'
    wait_for: /Started Server on (.+):(\\d+)/
    callback: (state, data) ->
      [match, address, port] = data

      server_port: port
      server_address: address
"""

test2_task_config = """
  module.exports = (state) ->
    name: 'Test2'
    command: ['echo running test2!']
    start_message: "Starting Test2 with Server Address: \#{state.server_address} and Server Port: \#{state.server_port}"
    wait_for: /running test2/
"""

return_non_object_config = """
  module.exports = (state) ->
    name: 'Return a non object in callback'
    command: 'echo AHHHHH!!!!'
    wait_for: ''
    args:
      nonobject:
        default: 'its a thing!'
    callback: -> false
"""

return_new_state_config = """
  module.exports = (state) ->
    name: 'Return new state'
    command: 'echo "It\\'s easy!"'
    wait_for: ''
    callback: (state, data) ->
      here: 'is some new state for ya'
"""

parallel 'state', ->

  it 'passes data from task to task', ->
    with_stacker
      cmd: 'test test2'
      task_config:
        test: test_task_config
        test2: test2_task_config
    , (stacker) ->
      stacker.wait_for /start message: Starting Test2 with Server Address: 127.0.0.1 and Server Port: 8080/

  it 'handles returning non-object from task callback', ->
    with_stacker
      cmd: 'test-return-non-object'
      task_config:
        'test-return-non-object': return_non_object_config
    , (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /nonobject=its a thing!/

  it 'copies state returned from callback onto existing state', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: return_new_state_config
    , (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for [
          /here=is some new state for ya/
        ]
