_ = require 'lodash'
fs = require 'fs'
util = require './util'
proc_lib = require './proc_lib'
{run_cmd} = require './run_cmd'
state_lib = require './state_lib'
task_config_lib = require './task_config'
_log = (args...) -> util.debug_log.apply null, [__filename].concat args

################################################################################
#  Run Tasks
#
# Starts all tasks, waiting until each previous task finishes starting
# before continuing
#
################################################################################
run_tasks = (tasks, initial_state) ->
  initial_state ?= state_lib.get_stacker_state()

  final = tasks.reduce (previous, task) ->
    previous.then((state) ->
      start_task(task, state)
    , (error) ->
      util.error 'Error handler:', error.stack
    ).catch (error) ->
      util.error 'Fail handler:', error.stack
  , Promise.resolve initial_state

  final.then ->
    if tasks.length > 0
      util.print 'Started all tasks!'.bold.green

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
  unless task_name
    return Promise.resolve()

  task_name = task_config_lib.resolve_task_name task_name

  if _(proc_lib.all_procs()).keys().includes(task_name) or _(proc_lib.all_daemons()).keys().includes(task_name)
    util.print task_name.cyan + ' is already running!'.yellow
    return Promise.resolve()

  unless task_config_lib.task_exists task_name
    util.log_error "Task does not exist: #{task_name}"
    return Promise.resolve()

  task_config = task_config_lib.get_task_config task_name, state_lib.get_stacker_state()

  if task_config.check?
    if not task_config.check()
      util.log_error "Task #{task_name} failed prestart check"
      return Promise.resolve()
    else
      util.print "Task #{task_name} passed prestart check".green

  # this needs refactored out, we need to do the daemon.is_running check before we print this (so the output makes more sense)
  util.print "Starting #{task_name.cyan}".yellow

  callback = task_config.callback ? (state) -> state

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

  promise.then (new_state) ->
    new_state = if _.isObject(new_state)
      _.assign({}, state_lib.get_stacker_state(), new_state)
    else
      state_lib.get_stacker_state()

    state_lib.set_stacker_state new_state
    new_state
  .catch (e) ->
    console.log 'starttask inner fail', e, e.stack

################################################################################
### Tasks
################################################################################

# fg_start_process = (task_name, task_config) ->
  # console.log 'ding fg start proc'
  # # mproc = start_process task_name, task_config

  # mproc.wait_for_once task_config.wait_for, (data) ->
  #   task_config.wait_for.exec?(data) ? [data]

# Str, Map, Str, fn -> (Promise -> proc, new_state)
start_foreground_task = (task_name, task_config, callback) ->
  mproc = start_process task_name, task_config

  mproc.on_data(task_config.wait_for).then (data) ->
    data = task_config.wait_for.exec?(data) ? [data]
    try
      new_state = callback state_lib.get_stacker_state(), data

      if task_config.start_message
        util.print "start message: #{task_config.start_message}"

      util.print "Started #{task_config.name}!".green
      return new_state
    catch e
      util.print "Failed to start #{task_config.name}!".bold
      _log e.stack
      return state_lib.get_stacker_state()


################################################################################
### Daemons
################################################################################


# Str, StackerENV, Str, Fn -> (Promise -> [proc, new_state, code, signal])
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
        throw new Error "Daemon start task exited with code #{code}"

      new_state = callback state_lib.get_stacker_state(), data # throws

      if task_config.start_message
        util.print "start message: #{task_config.start_message}"

      util.print "Started #{task_config.name}!".green

      proc_lib.add_daemon task_name, task_config

      new_state
    .catch (err) ->
      util.log_error err
      util.print "Failed to start #{task_config.name}!".red.bold
      # util.print err.stack if err.stack?

  if task_config.ignore_running_daemons
    util.print 'Skipping check to see if daemon is already running'.yellow
    return _start_daemon_task()

  util.print "Checking to see if #{task_name.cyan} is already running..."

  task_config.is_running.call(task_config).then (is_running) ->
    if is_running
      util.print "Found running #{task_name}!".green
      proc_lib.add_daemon task_name, task_config
      Promise.resolve()
    else
      util.print "Did not find running #{task_name.cyan}.  Starting..."
      _start_daemon_task()

  .catch (err) ->
    util.print err.message.red
    # util.print err.stack


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
# Str, TaskConfig -> Promise
kill_daemon_task = (task_name, task_config) ->
  util.print "Checking if #{task_name.cyan} is running..."

  _kill_daemon_task = ->
    util.print "#{'Killing daemon'.yellow} #{task_name.cyan}#{'...'.yellow}"

    run_cmd
      cmd: task_config.exit_command
      env: task_config.shell_env
      cwd: task_config.cwd
    .on_close.then ([code, signal]) ->
      if code is 0
        util.print "Stopped daemon #{task_name.cyan}".green + ' successfully!'.green
        proc_lib.remove_daemon task_name
      else
        util.print "Failed to stop daemon #{task_name.cyan}".yellow + '.  Maybe already dead?'.yellow
    .catch (err) ->
      console.log 'error: kill daemon task'
      console.log err

  if task_config.ignore_running_daemons
    return _kill_daemon_task()

  task_config.is_running().then (is_running) ->
    if is_running
      _kill_daemon_task()
    else
      util.print "#{task_name.cyan} already dead!"
      proc_lib.remove_daemon task_name


# Str, ChildProcess -> Promise
kill_foreground_task = (task_name, proc) ->
  new Promise (resolve, reject) ->
    proc.on 'close', ->
      resolve()

    util.print "Killing #{task_name.red}..."
    util.kill_tree proc.pid
  .catch (error) ->
    util.print 'Error killing'.red, task_name.cyan
    _log error.stack

# Str -> Promise
kill_task = (task_name) ->
  task_name = task_config_lib.resolve_task_name task_name

  proc = proc_lib.get_proc task_name
  daemon = proc_lib.get_daemon task_name

  unless proc or daemon
    util.print "No process or daemon matching '#{task_name.cyan}' found"
    return Promise.resolve()

  if proc
    proc_promise = kill_foreground_task task_name, proc

  if daemon
    daemon_promise = kill_daemon_task task_name, daemon

  Promise.all(_.compact([proc_promise, daemon_promise]))

# -> Promise
kill_running_tasks = ->
  util.print 'Killing all tasks...'.yellow
  Promise.all _(proc_lib.all_procs()).keys().map(kill_task).value()

exports = {
  start_task
  run_tasks
  kill_task
  kill_running_tasks
}

module.exports[k] = v for k, v of exports
