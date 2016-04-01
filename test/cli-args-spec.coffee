{Stacker} = require './helpers'

describe 'arguments', ->
  stacker = null

  afterEach (done) ->
    stacker.exit done

  it 'handles arguments from config file', ->
    stacker = new Stacker 'test'
    stacker.wait_for /Started all tasks!/
    .then ->
      stacker.send_cmd 'env'
      stacker.wait_for /config_argument=wonderful argument/

  it 'handles arguments from tasks', ->
    stacker = new Stacker 'test'
    stacker.wait_for /Started all tasks!/
    .then ->
      stacker.send_cmd 'env'
      stacker.wait_for /task_argument=such a good default/

  it 'converts - to _ in cli args', ->
    stacker = new Stacker '--testing-passing-a-hyphen'
    stacker.wait_for /Starting REPL/
    .then ->
      stacker.send_cmd 'env'
      stacker.wait_for /testing_passing_a_hyphen=true/
