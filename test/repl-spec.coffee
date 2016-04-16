parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

task_config = """
  module.exports = (state) ->
    name: 'Test'
    command: 'echo provide some output! && tail -f /dev/null'
    wait_for: /(output)/
"""

parallel 'repl commands', ->

  it 'help', ->
    with_stacker cmd: '', (stacker) ->
      stacker.send_cmd 'help'
      stacker.wait_for [
        /available commands/
        /tasks: print all tasks/
      ]

  it 'tell', ->
    with_stacker
      cmd: ''
      task_config:
        test: task_config
    , (stacker) ->
      stacker.send_cmd 'tell test echo butt'
      stacker.wait_for [
        /echo butt/
        /butt/
      ]

  it 'ps', ->
    with_stacker
      cmd: ''
      task_config:
        test: task_config
    , (stacker) ->
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
    with_stacker
      cmd: ''
      task_config:
        test: task_config
    , (stacker) ->
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
