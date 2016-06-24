parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'
_ = require 'lodash'

task_config_plain_js = """
  module.exports =
    name: 'Test Plain JS'
    command: ['echo', 'Started Plain JS!']
    wait_for: 'Started'
"""

task_config_fn = """
  module.exports = (state, util) ->
    name: 'Test Fn'
    command: ['echo', 'Started Fn!']
    wait_for: 'Started'
  """

parallel 'task config', ->
  it 'can use a config that is a plain JS object', ->
    with_stacker
      cmd: 'test'
      task_config:
        'test': task_config_plain_js
    , (stacker) ->
      stacker.wait_for /Started Plain JS!/

  it 'can use a config that is a fn', ->
    with_stacker
      cmd: 'test-fn'
      task_config:
        'test-fn': task_config_fn
    , (stacker) ->
      stacker.wait_for /Started Fn!/

stacker_config_plain_js = """
module.exports =
  args:
    config_argument:
      default: 'wonderful argument'
"""

stacker_config_fn = """
module.exports = ->
  args:
    config_argument:
      default: 'wonderful argument'
"""

parallel 'stacker config', ->
  it 'can use a config that is a plain JS object', ->
    with_stacker
      cmd: ''
      stacker_config: stacker_config_plain_js
    , (stacker) ->
      stacker.send_cmd 'env'
      stacker.wait_for /config_argument=wonderful argument/

  it 'can use a config that is a fn', ->
    with_stacker
      cmd: ''
      stacker_config: stacker_config_fn
    , (stacker) ->
      stacker.send_cmd 'env'
      stacker.wait_for /config_argument=wonderful argument/