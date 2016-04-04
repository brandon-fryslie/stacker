parallel = require 'mocha.parallel'
{with_stacker} = require './helpers'

parallel 'repl commands', ->

  it 'help', ->
    with_stacker '', (stacker) ->
      stacker.send_cmd 'help'
      stacker.wait_for [
        /available commands/
        /tasks: print all tasks/
      ]

  it 'tell', ->
    with_stacker '', (stacker) ->
      stacker.send_cmd 'tell test echo butt'
      # pipe_with_prefix '---- stacker output'.magenta, stacker.mproc.proc.stdout, process.stdout
      stacker.wait_for [
        /echo butt/
        /butt/
      ]

  it 'ps', ->
    with_stacker '', (stacker) ->
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
    with_stacker '', (stacker) ->
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
