parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

parallel 'help', ->

  it 'prints out tasks in usage', ->
    with_stacker '-h', (stacker) ->
      stacker.wait_for /Usage: stacker always-on-daemon cwd-missing/

  it 'includes cli args from config file and always prints args hyphenated', ->
    with_stacker '-h', (stacker) ->
      stacker.wait_for /--config-argument\s+good config arg  \[default: "wonderful argument"\]/

  it 'includes cli args from tasks', ->
    with_stacker '-h', (stacker) ->
      stacker.wait_for /--task-argument\s+one hell of an argument  \[default: "such a good default"\]/
