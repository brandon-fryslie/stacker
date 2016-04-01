{Stacker} = require './helpers'

describe 'help', ->
  stacker = null

  afterEach (done) ->
    stacker.exit done
    
  it 'prints out tasks in usage', ->
    stacker = new Stacker '-h'
    stacker.wait_for /Usage: stacker always-on-daemon cwd-missing/

  it 'includes cli args from config file and always prints args hyphenated', ->
    stacker = new Stacker '-h'
    stacker.wait_for /--config-argument\s+good config arg  \[default: "wonderful argument"\]/

  it 'includes cli args from tasks', ->
    stacker = new Stacker '-h'
    stacker.wait_for /--task-argument\s+one hell of an argument  \[default: "such a good default"\]/
