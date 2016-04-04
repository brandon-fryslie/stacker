parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

parallel 'arguments', ->

  it 'handles arguments from config file', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /config_argument=wonderful argument/

  it 'handles arguments from tasks', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /task_argument=such a good default/

  it 'converts - to _ in cli args', ->
    with_stacker '--testing-passing-a-hyphen', (stacker) ->
      stacker.wait_for /Starting REPL/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /testing_passing_a_hyphen=true/
