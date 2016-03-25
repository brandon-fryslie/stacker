require 'colors'
assert = require 'assert'
mexpect = require '../lib/mexpect'
{ pipe_with_prefix } = require '../lib/util'
_ = require 'lodash'

fs = require 'fs'
temp = require('temp')
path = require 'path'

class Stacker
  constructor: (cmd = '', env = {}) ->
    env.STACKER_CONFIG_DIR = "#{__dirname}/config"
    @mproc = mexpect.spawn
      cmd: "stacker #{cmd}"
      env: env
    # @engageOutput()

  wait_for: (expectation) ->
    @mproc.on_data expectation

  send_cmd: (cmd) ->
    @mproc.proc.stdin.write "#{cmd}\n"

  engageOutput: ->
    pipe_with_prefix '---- stacker output'.magenta, @mproc.proc.stdout, process.stdout

describe 'Stacker', ->
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

  it 'passes data from task to task', ->
    stacker = new Stacker 'test test2'
    stacker.wait_for /start message: test2 here, checking test data: just some passed thru test data/

  describe 'arguments', ->
    it 'handles arguments from config file', ->
      stacker = new Stacker 'test'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /config-argument=wonderful argument/

    it 'handles arguments from tasks', ->
      stacker = new Stacker 'test'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /task-argument=such a good default/

  describe 'repl commands', ->
    it 'help', ->
      stacker = new Stacker
      stacker.send_cmd 'help'
      stacker.wait_for [
        /available commands/
        /tasks: print all tasks/
      ]

    it 'tell', ->
      stacker = new Stacker
      stacker.send_cmd 'tell test echo butt'
      # pipe_with_prefix '---- stacker output'.magenta, stacker.mproc.proc.stdout, process.stdout
      stacker.wait_for [
        /echo butt/
        /butt/
      ]

    it 'ps', ->
      stacker = new Stacker
      stacker.send_cmd 'ps'
      stacker.wait_for([
        /No running procs!/
        /No running daemons!/
      ]).then ->
        stacker.send_cmd 'run test'
        stacker.wait_for(/Started Test!/).then ->
          stacker.send_cmd 'ps'
          stacker.wait_for(/stacker: test/).then ->
            stacker.send_cmd 'kill test'
            stacker.wait_for(/test exited with signal SIGKILL/).then ->
              stacker.send_cmd 'ps'
              stacker.wait_for(/No running procs!/)

    it 'setenv', ->
      stacker = new Stacker
      stacker.send_cmd 'setenv SOME_ENV_VARIABLE SOME_VALUE'
      stacker.send_cmd 'state'
      stacker.wait_for([
        /shell_env=/
        /  SOME_ENV_VARIABLE=SOME_VALUE/
      ]).then ->
        stacker.send_cmd 'run test'
        stacker.wait_for [
          /Starting test/
          /\$> SOME_ENV_VARIABLE=SOME_VALUE/
        ]

  describe 'daemons', ->
    it 'starts a daemon', ->
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
