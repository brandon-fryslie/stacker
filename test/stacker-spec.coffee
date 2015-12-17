assert = require 'assert'

mexpect = require '../lib/mexpect'

require 'colors'
{ spawn_and_match, assert_exit_status } = require './shelltest'

{ pipe_with_prefix } = require '../util/util'

class Stacker

  constructor: (cmd = '') ->
    @mproc = mexpect.spawn
      cmd: "stacker #{cmd}"
      close_stdin: false

  wait_for: (expectation) ->
    @mproc.on_data expectation

  send_cmd: (cmd) ->
    @mproc.proc.stdin.write "#{cmd}\n"

describe 'Stacker', ->
  it 'can start a foreground task', ->
    stacker = new Stacker 'test'
    stacker.wait_for(/Started Test!/).then ->
      stacker.wait_for /Started all tasks!/
    .catch (error) -> console.log error

  it 'can kill a foreground task', ->
    stacker = new Stacker 'test'
    stacker.wait_for(/Started all tasks!/).then ->
      stacker.send_cmd 'kill test'
      stacker.wait_for(/test exited with signal SIGKILL/)


  describe 'repl commands', ->
    it 'help', ->
      stacker = new Stacker
      stacker.send_cmd 'help'
      stacker.wait_for(/available commands/).then ->
        stacker.wait_for /tasks: print all tasks/


    it 'ps', ->
      stacker = new Stacker
      # pipe_with_prefix '---- stacker output'.magenta, stacker.mproc.proc.stdout, process.stdout
      stacker.send_cmd 'ps'
      Promise.all([
        stacker.wait_for(/No running procs!/)
        stacker.wait_for /No running daemons!/
      ]).then ->
        stacker.send_cmd 'run test'
        stacker.wait_for(/Started Test!/).then ->
          stacker.send_cmd 'ps'
          stacker.wait_for(/stacker: test/).then ->
            stacker.send_cmd 'kill test'
            stacker.wait_for(/test exited with signal SIGKILL/).then ->
              stacker.send_cmd 'ps'
              stacker.wait_for(/No running procs!/)


    describe 'daemons', ->

      it 'starts a daemon', ->
        stacker = new Stacker 'test-daemon'
        # pipe_with_prefix '---- stacker output'.magenta, stacker.mproc.proc.stdout, process.stdout
        stacker.wait_for(/start-test-daemon: Started all the test infrastructures!!/)


      it 'stops a daemon'

      it 'checks if a daemon is running'

      it 'does not start a daemon if it is already running'

      it 'throws error if daemon start process fails to produce expected output before exiting'