require 'colors'
fs = require 'fs'
path = require 'path'
assert = require 'assert'
mexpect = require '../lib/mexpect'
{pipe_with_prefix} = require '../lib/util'
_ = require 'lodash'

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
  stacker = null

  afterEach (done) ->
    stacker?.send_cmd 'exit'
    stacker?.wait_for(/Killed running tasks!/).then -> done()

    # This is to handle the case where stacker displays usage information and exits
    stacker?.wait_for(/☃/).then -> done()

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

  describe 'help', ->
    it 'prints out tasks in usage', ->
      stacker = new Stacker '-h'
      stacker.wait_for /Usage: stacker always-on-daemon cwd-missing/

    it 'includes cli args from config file and always prints args hyphenated', ->
      stacker = new Stacker '-h'
      stacker.wait_for /--config-argument\s+good config arg  \[default: "wonderful argument"\]/

    it 'includes cli args from tasks', ->
      stacker = new Stacker '-h'
      stacker.wait_for /--task-argument\s+one hell of an argument  \[default: "such a good default"\]/

  describe 'state', ->

    it 'passes data from task to task', ->
      stacker = new Stacker 'test test2'
      stacker.wait_for /start message: test2 here, checking test data: just some passed thru test data/

    it 'handles returning non-object from task callback', ->
      stacker = new Stacker 'test-return-non-object'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /nonobject=its a thing!/

    it 'copies state returned from callback onto existing state', ->
      stacker = new Stacker 'test-return-new-state'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for [
          /here=is some new state for ya/
        ]

  describe 'arguments', ->
    it 'handles arguments from config file', ->
      stacker = new Stacker 'test'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /config_argument=wonderful argument/

    it 'handles arguments from tasks', ->
      stacker = new Stacker 'test'
      stacker.wait_for /Started all tasks!/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /task_argument=such a good default/

    it 'converts - to _ in cli args', ->
      stacker = new Stacker '--testing-passing-a-hyphen'
      stacker.wait_for /Starting REPL/
      .then ->
        stacker.send_cmd 'env'
        stacker.wait_for /testing_passing_a_hyphen=true/

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
