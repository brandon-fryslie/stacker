{Stacker} = require './helpers'
_ = require 'lodash'

describe 'Daemon', ->
  stacker = null

  afterEach (done) ->
    stacker.exit done

  it 'starts a daemon', =>
    stacker = new Stacker 'test-daemon'
    stacker.wait_for [
      /start-test-daemon: Started all the test infrastructures!!/
      /Started Test Daemon!/
    ]

  it 'stops a daemon', ->
    stacker = new Stacker 'always-on-daemon'
    stacker.send_cmd 'kill always-on-daemon'
    stacker.wait_for(/stacker: Stopped daemon always-on-daemon successfully!/)

  it 'checks if a daemon is running', ->
    stacker = new Stacker
    stacker.send_cmd 'r? always-on-daemon'
    stacker.wait_for [
      /Checking to see if always-on-daemon is running.../
      /always-on-daemon is running/
    ]

  it 'does not start a daemon if it is already running', ->
    stacker = new Stacker
    stacker.send_cmd 'run always-on-daemon'
    stacker.wait_for [
      /Checking to see if always-on-daemon is already running.../
      /Found running always-on-daemon!/
    ]

  it 'throws error if daemon start process fails to produce expected output before exiting', ->
    stacker = new Stacker 'fail-daemon'
    stacker.wait_for [
      /Error: Failed to see expected output when starting fail-daemon/
      /Failed to start Fail Daemon!/
    ]

  it 'throws error if task has an invalid working directory', ->
    stacker = new Stacker 'cwd-missing'
    stacker.wait_for /This task has an invalid working directory \(\/bla\/bla\/bla\)\./
