parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

parallel 'Stacker', ->

  it 'can start a foreground task', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]

  it 'can start task by alias', ->
    with_stacker 't', (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]

  it 'cannot start same task twice', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for [
        /Started Test!/
        /Started all tasks!/
      ]
      .then ->
        stacker.send_cmd 'run test'
        stacker.wait_for /is already running/

  it 'can kill a foreground task', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for(/Started all tasks!/).then ->
        stacker.send_cmd 'kill test'
        stacker.wait_for /test exited with signal SIGKILL/

  it 'passes additional shell env variables', ->
    with_stacker 'test', (stacker) ->
      stacker.wait_for [
        /\$> KAFKA_QUEUE_TYPE=NIGHTMARE tail -f/
        /Started Test!/
        /Started all tasks!/
      ]
