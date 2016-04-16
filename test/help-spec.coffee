parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

task_config = """
  module.exports = (state) ->
    name: 'Test'
    command: 'echo provide some output! && tail -f /dev/null'
    args:
      task_argument:
        describe: 'one hell of an argument'
        default: 'such a good default'
    wait_for: /(output)/
"""

stacker_config = """
module.exports =
  args:
    config_argument:
      describe: 'good config arg'
      default: 'wonderful argument'
"""

parallel 'help', ->

  it 'prints out tasks in usage', ->
    with_stacker
      cmd: '-h'
      task_config:
        'a-wild-task-appears': task_config
    , (stacker) ->
      stacker.wait_for /Usage: stacker a-wild-task-appears/

  it 'includes cli args from config file and always prints args hyphenated', ->
    with_stacker
      cmd: '-h'
      stacker_config: stacker_config
    , (stacker) ->
      stacker.wait_for /--config-argument\s+good config arg  \[default: "wonderful argument"\]/

  it 'includes cli args from tasks', ->
    with_stacker
      cmd: '-h'
      task_config:
        test: task_config
    , (stacker) ->
      stacker.wait_for /--task-argument\s+one hell of an argument  \[default: "such a good default"\]/
