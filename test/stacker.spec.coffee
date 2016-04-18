fs = require 'fs'
_ = require 'lodash'
temp = require('temp').track()
parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

test_config = """
  module.exports = (state) ->
    name: 'Test'
    alias: 't'
    shell_env:
      KAFKA_QUEUE_TYPE: 'NIGHTMARE'
    command: 'echo provide some output! && tail -f /dev/null'
    wait_for: /(output)/
"""

parallel 'Stacker', ->

  it 'can start a foreground task', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]

  it 'can start task by alias', ->
    with_stacker
      cmd: 't'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]

  it 'cannot start same task twice', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]
      .then ->
        stacker.send_cmd 'run test'
        stacker.wait_for /is already running/

  it 'can kill a foreground task', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for(/Started all tasks!/).then ->
        stacker.send_cmd 'kill test'
        stacker.wait_for /test exited with signal SIGKILL/

  it 'passes additional shell env variables', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: test_config
    , (stacker) ->
      stacker.wait_for [
        /\$> KAFKA_QUEUE_TYPE=NIGHTMARE echo prov/
        /Started Test!/
        /Started all tasks!/
      ]
