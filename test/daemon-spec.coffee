parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'
_ = require 'lodash'

parallel 'Daemon', ->

  it 'starts a daemon', ->
    with_stacker 'test-daemon', (stacker) ->
      stacker.wait_for [
        /start-test-daemon: Started all the test infrastructures!!/
        /Started Test Daemon!/
      ]

  it 'stops a daemon', ->
    with_stacker 'always-on-daemon', (stacker) ->
      stacker.send_cmd 'kill always-on-daemon'
      stacker.wait_for(/stacker: Stopped daemon always-on-daemon successfully!/)

  it 'checks if a daemon is running', ->
    with_stacker '', (stacker) ->
      stacker.send_cmd 'r? always-on-daemon'
      stacker.wait_for [
        /Checking to see if always-on-daemon is running.../
        /always-on-daemon is running/
      ]

  it 'does not start a daemon if it is already running', ->
    with_stacker '', (stacker) ->
      stacker.send_cmd 'run always-on-daemon'
      stacker.wait_for [
        /Checking to see if always-on-daemon is already running.../
        /Found running always-on-daemon!/
      ]

  it 'throws error if daemon start process fails to produce expected output before exiting', ->
    with_stacker 'fail-daemon', (stacker) ->
      stacker.wait_for [
        /Error: Failed to see expected output when starting fail-daemon/
        /Failed to start Fail Daemon!/
      ]

  it 'throws error if task has an invalid working directory', ->
    with_stacker 'cwd-missing', (stacker) ->
      stacker.wait_for /This task has an invalid working directory \(\/bla\/bla\/bla\)\./
