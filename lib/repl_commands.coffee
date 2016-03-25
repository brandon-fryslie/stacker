_ = require 'lodash'
proc_lib = require './proc'
repl_lib = require './repl'
task_lib = require './task'
state_lib = require './state'
task_config_lib = require './task_config'
util = require './util'

invalid_command_invocation = (cmd) ->
  util.log_error "usage: #{cmd.usage}"
  Promise.resolve()

################################################################################
#  Process Status
#
#  TODO: what cool stuff can we show?
#  - Runtime
#  - PID
#  - Git branch?!
#  - Version #??
################################################################################
processes_running = ->
  repl_lib.print "What's running".cyan
  repl_lib.print if _.keys(proc_lib.all_procs()).length
    ("#{k}\n" for k, v of proc_lib.all_procs()).join('')
  else
    'No running procs!'.bold.cyan

  repl_lib.print if _.keys(proc_lib.all_daemons()).length
    "\n#{'Daemons'.cyan}\n#{("#{k}\n" for k, v of proc_lib.all_daemons()).join('')}"
  else
    'No running daemons!'.bold.cyan

repl_lib.add_command
  name: 'ps'
  help: 'status of running processes'
  fn: processes_running

################################################################################
#  Daemons
################################################################################
repl_lib.add_command
  name: 'ds'
  help: 'status of daemons'
  fn: ->
    repl_lib.print "Daemons".cyan

    repl_lib.print if _.keys(proc_lib.all_daemons()).length
      "#{("#{k}\n" for k, v of proc_lib.all_daemons()).join('')}"
    else
      'No running daemons!'.bold.cyan

repl_lib.add_command
  name: 'nuke'
  help: 'kill -9 java'
  fn: (task) ->
    child_process.exec 'killall -9 java', (error, stdout, stderr) ->
      if error
        repl_lib.print error.message.red
        return
      repl_lib.print 'Nuking All Javas!'.magenta
      repl_lib.print stdout
      if stderr
        repl_lib.print stderr.red

repl_lib.add_command
  name: 'help'
  alias: 'h'
  help: "'help' helps you get help for commands such as 'help'"
  fn: ->
    repl_lib.print 'available commands'.cyan.bold
    strs = for {name, help, usage, alias} in _.values(repl_lib.get_commands())
      str = "#{name.cyan}: #{help}\n"
      str += "usage: #{usage}\n" if usage
      str += "alias: #{alias}\n" if alias
      str

    repl_lib.print strs.join '\n'

repl_lib.add_command
  name: 'state'
  alias: 'env'
  help: 'print information about the stacker state'
  fn: ->
    repl_lib.print 'STACKER STATE'.cyan.bold
    repl_lib.print util.beautify_obj(state_lib.get_stacker_state())

repl_lib.add_command
  name: 'set'
  alias: 's'
  help: 'set environment variable'
  usage: 'set [KEY] [VALUE]'
  fn: (k, v) ->
    unless k? and v?
      return invalid_command_invocation @

    repl_lib.print 'setting'.cyan.bold, "#{k}".blue.bold, 'to'.cyan.bold, "#{v}".magenta

    # gotta love boolean coersion in js
    v = if v is 'false' then false else v
    v = if v is 'true'  then true  else v

    state_lib.get_stacker_state()[k] = v

################################################################################
# REPL TELL
#
# tell someone to do something
#
# usage: tell [TARGET(S)] [SOMETHING TO DO]
# e.g. tell alm grunt clean build
#
# looks for a task by name, otherwise looks for a directory in ~/projects
#
# can use a comma-separated list of targets
# e.g. tell alm,appsdk,app-catalog,churro grunt clean build
################################################################################
# (string, [string]) -> null
tell_target = (target, cmd) ->
  try
    path = if task_config_lib.task_exists(target)
      task_config_lib.read_task_property(target, 'cwd') ? process.cwd()
    else if fs.statSync("#{process.env.HOME}/projects/#{target}")?.isDirectory()
      "#{process.env.HOME}/projects/#{target}"
  catch e
    unless e.code is 'ENOENT' # handle missing directory below
      throw e

  unless path?
    repl_lib.print "'#{target}' is not a task name or a directory in ~/projects".red
    return

  task_lib.run_cmd
    cmd: cmd
    cwd: path

repl_lib.add_command
  name: 'tell'
  alias: 't'
  tab_complete: (args) ->
    ['ronald', 'mc', 'donald']
  help: 'tell someone to do something (e.g. tell alm grunt clean build)'
  usage: 'tell [TASK] [COMMAND]'
  fn: (target, cmd...) ->
    unless target? and cmd.length
      return invalid_command_invocation @

    targets = target.split ','
    _.map targets, (target) -> tell_target target, cmd

# (string, [string]) -> null
cleanup_task = (target) ->
  unless target?
    return invalid_command_invocation @

  task_name = task_config_lib.resolve_task_name target

  unless task_config_lib.task_exists task_name
    util.log_error "Task does not exist: #{task_name}"
    return Promise.resolve()

  task_config = task_config_lib.get_task_config task_name

  task_config.cleanup.call(task_config).then ([code, signal]) ->
    if code is 0
      repl_lib.print "#{'Cleaned up'.green} #{task_name.cyan} #{'successfully!'.green}"
    else
      repl_lib.print "#{'Clean up task failed for'.yellow} #{task_name.cyan}#{'.'.yellow}"

repl_lib.add_command
  name: 'cleanup'
  alias: 'cu'
  help: 'run cleanup for a task'
  usage: 'cleanup [TASK]'
  fn: cleanup_task

# (string, [string]) -> null
is_daemon_running = (target) ->
  unless target?
    return invalid_command_invocation @

  task_name = task_config_lib.resolve_task_name target

  unless task_config_lib.task_exists task_name
    util.log_error "Task does not exist: #{task_name}"
    return Promise.resolve()

  task_config = task_config_lib.get_task_config task_name

  stop_indicator = repl_lib.start_progress_indicator()

  repl_lib.print "Checking to see if #{task_name.cyan} is running..."

  task_config.is_running.call(task_config).then (is_running) ->
    stop_indicator()
    if is_running
      repl_lib.print "#{task_name.cyan} #{'is running'.green}"
    else
      repl_lib.print "#{task_name.cyan} #{'is not running'.green}"

repl_lib.add_command
  name: 'running'
  alias: 'r?'
  help: 'is daemon runnning?'
  usage: 'running [TASK]'
  fn: is_daemon_running

repl_lib.add_command
  name: 'tasks'
  help: 'print all tasks'
  fn: ->
    repl_lib.print 'tasks:', (_(task_config_lib.get_task_config_map()).keys().value().join ' ').cyan

repl_lib.add_command
  name: 'kill'
  alias: 'k'
  help:'kill a task'
  usage:'kill [TASK]'
  fn: (target) ->
    unless target?
      return invalid_command_invocation @

    task_lib.kill_task target

repl_lib.add_command
  name: 'killall'
  alias: 'ka'
  help:'kill all running processes'
  fn: task_lib.kill_running_tasks

repl_lib.add_command
  name: 'restart'
  alias: 'rs'
  help: 'restart a task'
  usage: 'restart [TASK]'
  fn: (target) ->
    unless target?
      return invalid_command_invocation @

    repl_lib.print "Restarting #{target}..."
    task_lib.kill_task(target).then ->
      task_lib.start_task(target)

repl_lib.add_command
  name: 'run'
  alias: 'r'
  help: 'start multiple tasks'
  usage: 'run [TASKS]'
  fn: (tasks...) ->
    unless tasks.length
      return invalid_command_invocation @

    task_lib.run_tasks tasks

repl_lib.add_command
  name: 'setenv'
  help: 'set a shell environment variable'
  usage: 'setenv [KEY] [VALUE]'
  fn: (k, v) ->
    unless k? and v?
      return invalid_command_invocation @

    repl_lib.print 'setting shell environment variable'.cyan.bold, "#{k}".blue.bold, 'to'.cyan.bold, "#{v}".magenta

    state = state_lib.get_stacker_state()
    state.shell_env ?= {}
    state.shell_env[k] = v
    state_lib.set_stacker_state state
