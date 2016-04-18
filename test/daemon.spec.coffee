parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'
_ = require 'lodash'

task_config = """
  module.exports = (state) ->
    name: 'Test Daemon'
    command: ['echo', 'Started all the test infrastructures!!']
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve false
    cleanup: ->
      util.print 'Cleaning things up!  For serious'.yellow
      run_cmd
        cmd: ['echo', 'Cleaning up after test daemon...']
      .on_close
    start_message: 'test daemon procs'
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command run!']
"""

always_on_daemon_config = """
  module.exports = (state, util) ->
    name: 'Always on daemon'
    command: ['echo', 'Started all the test infrastructures!!']
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve true
    cleanup: ->
      util.print 'Cleaning things up!  For serious'.yellow
      run_cmd
        cmd: ['echo', 'Cleaning up after test daemon...']
      .on_close
    start_message: 'daemon is always running'
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command run!']
  """

fail_daemon_config = """
  module.exports = (state) ->
    name: 'Fail Daemon'
    command: ['echo some stuff']
    wait_for: /Neva gonna happen/
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve false
    start_message: 'should never see this!'
"""

cwd_missing_config = """
  module.exports = (state, util) ->
    command: ['echo', 'pillow']
    cwd: '/bla/bla/bla'
"""

parallel 'Daemon', ->

  it 'starts a daemon', ->
    with_stacker
      cmd: 'test-daemon'
      task_config:
        'test-daemon': task_config
    , (stacker) ->
      stacker.wait_for [
        /start-test-daemon: Started all the test infrastructures!!/
        /Started Test Daemon!/
      ]

  it 'stops a daemon', ->

    with_stacker
      cmd: 'always-on-daemon'
      task_config:
        'always-on-daemon': always_on_daemon_config
    , (stacker) ->
      stacker.send_cmd 'kill always-on-daemon'
      stacker.wait_for(/stacker: Stopped daemon always-on-daemon successfully!/)

  it 'checks if a daemon is running', ->
    with_stacker
      cmd: ''
      task_config:
        'always-on-daemon': always_on_daemon_config
    , (stacker) ->
      stacker.send_cmd 'r? always-on-daemon'
      stacker.wait_for [
        /Checking to see if always-on-daemon is running.../
        /always-on-daemon is running/
      ]

  it 'does not start a daemon if it is already running', ->
    with_stacker
      cmd: ''
      task_config:
        'always-on-daemon': always_on_daemon_config
    , (stacker) ->
      stacker.send_cmd 'run always-on-daemon'
      stacker.wait_for [
        /Checking to see if always-on-daemon is already running.../
        /Found running always-on-daemon!/
      ]

  it 'throws error if daemon start process fails to produce expected output before exiting', ->
    with_stacker
      cmd: 'fail-daemon'
      task_config:
        'fail-daemon': fail_daemon_config
    , (stacker) ->
      stacker.wait_for [
        /Error: Failed to see expected output when starting fail-daemon/
        /Failed to start Fail Daemon!/
      ]

  it 'throws error if task has an invalid working directory', ->
    with_stacker
      cmd: 'test'
      task_config:
        test: cwd_missing_config
    , (stacker) ->
      stacker.wait_for /This task has an invalid working directory \(\/bla\/bla\/bla\)\./
