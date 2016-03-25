_ = require 'lodash'
env_lib = require './env'
repl_lib = require './repl'
proc_lib = require './proc'
proc_util = require './proc_util'
task_config_lib = require './task_config'
mexpect = require './mexpect'
util = require './util'
fs = require 'fs'

################################################################################
#  Run Tasks
#
# Starts all tasks, waiting until each previous task finishes starting
# before continuing
#
################################################################################
run_tasks = (tasks, initial_env) ->
  initial_env ?= env_lib.get_stacker_env()

  final = tasks.reduce (previous, task) ->
    previous.then((env) ->
      start_task(task, env)
    , (error) ->
      util.error 'Error handler:', error.stack
    ).catch (error) ->
      util.error 'Fail handler:', error.stack
  , Promise.resolve initial_env

  final.then ->
    if tasks.length > 0
      repl_lib.print 'Started all tasks!'.bold.green

################################################################################
#  Start one task
#  Returns a promise
#
#  a task is either a process or a daemon
#
#  a process is attached to stdout
################################################################################

# Main fn of program.
# Pulls task config, gets shell env, prints some stuff, decides how to
# start the process, then starts it
#
# Str, StackerENV -> (Promise -> StackerENV)
start_task = (task_name) ->
  new Promise (resolve, reject) ->
    unless task_name
      return Promise.resolve()

    task_name = task_config_lib.resolve_task_name task_name

    if _(proc_lib.all_procs()).keys().includes(task_name) or _(proc_lib.all_daemons()).keys().includes(task_name)
      util.repl_print task_name.cyan + ' is already running!'.yellow
      return Promise.resolve()

    unless task_config_lib.task_exists task_name
      util.log_error "Task does not exist: #{task_name}"
      return Promise.resolve()

    task_config = task_config_lib.get_task_config task_name, env_lib.get_stacker_env()

    if task_config.check?
      if !task_config.check()
        util.log_error "Task #{task_name} failed prestart check"
        return Promise.resolve()
      else
        util.repl_print "Task #{task_name} passed prestart check".green

    # this needs refactored out, we need to do the daemon.is_running check before we print this (so the output makes more sense)
    repl_lib.print "Starting #{task_name.cyan}".yellow

    callback = task_config.callback ? (_, env) -> env

    # try # maybe clone repo hey why not
    #   cwd = task_config.cwd ? require.main.filename.replace(/\/[\w\-_]+$/, '')
    #   fs.statSync(cwd).isDirectory()
    # catch e
    #   repo_name = task_config.cwd.replace(/.*\/([\w\-_]+)$/, '$1')
    #   return try_to_clone task_name, repo_name
    # # / clone

    promise = if task_config.exit_command?
      start_daemon_task task_name, task_config, callback
    else
      start_foreground_task task_name, task_config, callback

    promise.then (new_env) ->
      env_lib.set_stacker_env new_env
      resolve new_env
    .catch (e) ->
      console.log 'starttask inner fail', err, err.stack
  .catch (e) ->
    repl_lib.print e.message.red
    util._log e.stack

################################################################################
### Tasks
################################################################################

# fg_start_process = (task_name, task_config) ->
  # console.log 'ding fg start proc'
  # # mproc = start_process task_name, task_config

  # mproc.wait_for_once task_config.wait_for, (data) ->
  #   task_config.wait_for.exec?(data) ? [data]

# Str, Map, Str, fn -> (Promise -> proc, new_env)
start_foreground_task = (task_name, task_config, callback) ->
  mproc = start_process task_name, task_config

  mproc.on_data(task_config.wait_for).then (data) ->
    data = task_config.wait_for.exec?(data) ? [data]
    try
      new_env = callback data, env_lib.get_stacker_env()

      if task_config.start_message
        repl_lib.print "start message: #{task_config.start_message}"

      repl_lib.print "Started #{task_config.name}!".green
      return new_env
    catch e
      repl_lib.print "Failed to start #{task_config.name}!".bold
      util._log e.stack
      return env_lib.get_stacker_env()

# Run a command
# if id is passed in, will prefix output with that
# ({cmd: [string], task_name: string, cwd: string, env: map, silent: boolean, pipe_output: boolean}) -> child_process
run_cmd = ({cmd, id, cwd, env, silent, pipe_output, close_stdin, direct}) ->
  shell_env = _.assign {}, env_lib.get_stacker_env().shell_env, env

  cwd ?= process.cwd()

  missing_dir_error = "This task has an invalid working directory (#{cwd}).  Please check your configuration."
  try
    unless fs.statSync(cwd).isDirectory()
      throw new Error missing_dir_error
  catch e
    throw new Error missing_dir_error

  silent ?= false
  pipe_output ?= true
  close_stdin ?= true
  direct ?= false
  env = env_lib.get_shell_env shell_env

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
    repl_lib.print util.pretty_command_str cmd, shell_env

  mproc


################################################################################
### Daemons
################################################################################


# Str, StackerENV, Str, Fn -> (Promise -> [proc, new_env, code, signal])
#
# Main entry point for starting daemon tasks
#
# I understand this is horrible
#
# Will check if the daemon task is already running according to
# the 'is_running' task config property
start_daemon_task = (task_name, task_config, callback) ->

  # i hate stuff like this
  _start_daemon_task = ->

    run_mexpect_process(task_name, task_config).then ([data, code, signal]) ->
      unless code is 0
        throw "Daemon start task exited with code #{code}"

      new_env = callback(data, env_lib.get_stacker_env()) # throws

      if task_config.start_message
        repl_lib.print "start message: #{task_config.start_message}"

      repl_lib.print "Started #{task_config.name}!".green

      proc_lib.add_daemon task_name, task_config

      new_env
    .catch (err) ->
      util.log_error err
      repl_lib.print "Failed to start #{task_config.name}!".red.bold
      # repl_lib.print err.stack if err.stack?

  if task_config.ignore_running_daemons
    repl_lib.print 'Skipping check to see if daemon is already running'.yellow
    return _start_daemon_task()

  repl_lib.print "Checking to see if #{task_name.cyan} is already running..."

  task_config.is_running.call(task_config).then (is_running) ->
    if is_running
      repl_lib.print "Found running #{task_name}!".green
      proc_lib.add_daemon task_name, task_config
      Promise.resolve()
    else
      repl_lib.print "Did not find running #{task_name.cyan}.  Starting..."
      _start_daemon_task()

  .catch (err) ->
    repl_lib.print err.message.red
    # repl_lib.print err.stack


# (task_name, task_config) -> (Promise -> [data, code, signal])
# for daemons
run_mexpect_process = (task_name, task_config) ->
  mproc = start_process "start-#{task_name}", task_config

  promise = if task_config.wait_for?
    wait_for_promise = mproc.on_data(task_config.wait_for)
    mproc.on_close.then ([code, signal]) ->

      unless wait_for_promise._state # will be 1 if promise is fulfilled
        throw new Error "#{'Failed to see expected output when starting'.red} #{task_name.cyan}"

      wait_for_promise.then (data) ->
        [data, code, signal]

  else
    mproc.on_close.then ([code, signal]) -> [[], code, signal]

  promise.then (args) ->
    proc_lib.remove_proc task_name
    args
################################################################################
### / Daemons
################################################################################

start_process = (id, task_config) ->
  mproc = run_cmd
    id: id
    cmd: task_config.command
    env: task_config.shell_env
    cwd: task_config.cwd
    verbose: false
    direct: true

  # mproc.proc.on 'error', util.log_proc_error

  mproc

################################################################################
#  Kill task
################################################################################
# Int, Str -> ?
kill_tree = (pid, signal='SIGKILL') ->
  psTree = require('ps-tree')
  psTree pid, (err, children) ->
    [pid].concat(_.map(children, 'PID')).forEach (pid) ->
      try
        process.kill(pid, signal)
      catch e
        # util.error 'Error: Trying to kill', e.stack

# Str, TaskConfig -> Promise
kill_daemon_task = (task_name, task_config) ->
  repl_lib.print "Checking if #{task_name.cyan} is running..."

  _kill_daemon_task = ->
    repl_lib.print "#{'Killing daemon'.yellow} #{task_name.cyan}#{'...'.yellow}"

    run_cmd
      cmd: task_config.exit_command
      env: task_config.shell_env
      cwd: task_config.cwd
    .on_close.then ([code, signal]) ->
      if code is 0
        repl_lib.print "Stopped daemon #{task_name.cyan}".green + " successfully!".green
        proc_lib.remove_daemon task_name
      else
        repl_lib.print "Failed to stop daemon #{task_name.cyan}".yellow + ".  Maybe already dead?".yellow
    .catch (err) ->
      console.log 'error: kill daemon task'
      console.log err

  if task_config.ignore_running_daemons
    return _kill_daemon_task()

  task_config.is_running().then (is_running) ->
    if is_running
      _kill_daemon_task()
    else
      repl_lib.print "#{task_name.cyan} already dead!"
      proc_lib.remove_daemon task_name


# Str, ChildProcess -> Promise
kill_foreground_task = (task_name, proc) ->
  new Promise (resolve, reject) ->
    proc.on 'close', ->
      resolve()

    kill_tree proc.pid
    repl_lib.print "Killing #{task_name.red}..."
  .catch (error) -> console.log error

# Str -> Promise
kill_task = (task_name) ->
  task_name = task_config_lib.resolve_task_name task_name

  proc = proc_lib.get_proc task_name
  daemon = proc_lib.get_daemon task_name

  unless proc or daemon
    repl_lib.print "No process or daemon matching '#{task_name.cyan}' found"
    return Promise.resolve()

  if proc
    proc_promise = kill_foreground_task task_name, proc

  if daemon
    daemon_promise = kill_daemon_task task_name, daemon

  Promise.all(_.compact([proc_promise, daemon_promise]))

# -> Promise
kill_running_tasks = ->
  repl_lib.print "Killing all tasks...".yellow
  Promise.all _(proc_lib.all_procs()).keys().map(kill_task).value()

module.exports = {
  run_cmd
  start_task
  run_tasks
  kill_task
  kill_running_tasks
}
