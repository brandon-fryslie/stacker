fs = require 'fs'
_ = require 'lodash'
state_lib = require './state'
mexpect = require './mexpect'
repl_lib = require './repl_lib'
util = require './util'
proc_lib = require './proc'
proc_util = require './proc_util'

module.exports =
  # Run a command
  # if id is passed in, will prefix output with that
  # ({cmd: [string], task_name: string, cwd: string, env: map, silent: boolean, pipe_output: boolean}) -> child_process
 ({cmd, id, cwd, env, silent, pipe_output, close_stdin, direct}) ->
    shell_env = _.assign {}, state_lib.get_stacker_state().shell_env, env

    cwd ?= process.cwd()

    missing_dir_error = "This task has an invalid working directory (#{cwd}).  Please check your configuration."
    try
      unless fs.statSync(cwd).isDirectory()
        throw new Error missing_dir_error
    catch e
      console.log e.stack
      throw new Error missing_dir_error

    silent ?= false
    pipe_output ?= true
    close_stdin ?= true
    direct ?= false
    env = state_lib.get_shell_env shell_env

    mproc = mexpect.spawn
      id: id
      cmd: cmd
      cwd: cwd
      env: env
      silent: silent
      pipe_output: pipe_output

    stop_indicator = repl_lib.start_progress_indicator()
    mproc.proc.stdout.on 'readable', stop_indicator
    mproc.proc.stdout.on 'data', stop_indicator
    mproc.proc.stderr.on 'readable', stop_indicator
    mproc.proc.stderr.on 'data', stop_indicator

    child_id = id ? "#{util.regex_extract(/\/([\w-]+)$/, cwd)}-#{cmd.join('-')}-#{mproc.proc.pid}".replace(/\s/g, '-')

    mproc.on_close.then ([exit_code, signal]) ->
      proc_lib.remove_proc child_id
      unless silent
        proc_util.print_process_status child_id, exit_code, signal
      kill_tree mproc.proc.pid
    .catch (error) -> console.log error

    proc_lib.add_proc child_id, mproc.proc

    if pipe_output
      util.prefix_pipe_output child_id, mproc.proc

    if close_stdin
      mproc.proc.stdin.end()

    unless silent
      util.print util.pretty_command_str cmd, shell_env

    mproc
