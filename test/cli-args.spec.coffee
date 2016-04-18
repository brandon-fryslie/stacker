parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

test_config = """
  module.exports = (state) ->
    name: 'Test'
    command: 'echo provide some output! && tail -f /dev/null'
    args:
      important_setting:
        default: 'such a good default'
    wait_for: /(output)/
"""

stacker_config = """
module.exports =
  args:
    config_argument:
      default: 'wonderful argument'
"""

parallel 'arguments', ->

  it 'handles arguments from config file', ->
    with_stacker
      cmd: 'test'
      task_config: test: test_config
      stacker_config: stacker_config
    , (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /config_argument=wonderful argument/

  it 'handles arguments from tasks', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /important_setting=such a good default/

  it 'converts - to _ in cli args', ->
    with_stacker
      cmd: '--testing-passing-a-hyphen'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for /Starting REPL/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /testing_passing_a_hyphen=true/
