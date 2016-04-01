{Stacker} = require './helpers'

describe 'Stacker', ->
  stacker = null

  afterEach (done) ->
    stacker.exit done

  it 'can start a foreground task', ->
    stacker = new Stacker 'test'
    stacker.wait_for [
      /Started Test!/
      /Started all tasks!/
    ]

  it 'can start task by alias', ->
    stacker = new Stacker 't'
    stacker.wait_for [
      /Started Test!/
      /Started all tasks!/
    ]

  it 'cannot start same task twice', ->
    stacker = new Stacker 'test'
    stacker.wait_for [
      /Started Test!/
      /Started all tasks!/
    ]
    .then ->
      stacker.send_cmd 'run test'
      stacker.wait_for /is already running/

  it 'can kill a foreground task', ->
    stacker = new Stacker 'test'
    stacker.wait_for(/Started all tasks!/).then ->
      stacker.send_cmd 'kill test'
      stacker.wait_for /test exited with signal SIGKILL/

  it 'passes additional shell env variables', ->
    stacker = new Stacker 'test'
    stacker.wait_for [
      /\$> KAFKA_QUEUE_TYPE=NIGHTMARE tail -f/
      /Started Test!/
      /Started all tasks!/
    ]
