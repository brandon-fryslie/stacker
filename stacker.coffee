#!/usr/bin/env coffee

colors = require 'colors'
Q = require 'q'
_ = require 'lodash'
mexpect = require './mexpect'
repl_lib = require './repl'
util = require './util'
child_process = require 'child_process'
fs = require 'fs'

ZSHMIN =
  """ZSH=$HOME/.oh-my-zsh
ZSH_CUSTOM=$HOME/.oh-my-zsh-custom
ZSH_THEME="git-taculous"
plugins=(emacs java alm appsdk git gls rally)
source $ZSH/oh-my-zsh.sh
export TERM=xterm-256color"""

# Run a command
# ([string], string, map) -> child_process
run_cmd = (cmd, cwd=process.cwd(), env=GET_ENV()) ->
  child = child_process.spawn 'zsh', [],
    cwd: cwd
    env: env

  child.stdin.write(ZSHMIN + '\n')
  child.stdin.write(cmd.join(' ') + '\n')
  child.stdin.end()

  child_id = "#{util.regex_extract(/\/([\w-]+)$/, cwd)}-#{cmd.join('-')}-#{child.pid}"

  stop_indicator = repl_lib.start_progress_indicator()

  child.stdout.on 'readable', stop_indicator
  child.stdout.on 'data', stop_indicator
  child.stderr.on 'readable', stop_indicator
  child.stderr.on 'data', stop_indicator

  child.on 'close', (exit_code, signal) ->
    delete PROCS[child_id]
    print_process_status child_id, exit_code, signal

  PROCS[child_id] = child

  repl_lib.print '$>'.gray, "#{'cd'.green} #{cwd.cyan}#{';'.green}", "#{cmd.join(' ')}".green
  prefix = util.get_color_fn()("#{child_id}:")
  util.pipe_with_prefix prefix, child.stdout, process.stdout
  util.pipe_with_prefix prefix, child.stderr, process.stderr

  child

################################################################################
# Current REPL environment - keeps track of verbose/quiet, using appsdk/churro/whatever
################################################################################
CURRENT_ENV = {}
ENV_PROPERTY_BLACKLIST = ['start_message', 'name', 'alias', 'command', 'wait_for', 'callback', 'additional_env', 'cwd']
SET_ENV = (env) ->
  unless env?
    throw new Error "You shouldn't null out the ENV.  Make sure to return ENV from your task handlers"

  env = _.cloneDeep env

  # dont save the state of some properties
  for p in ENV_PROPERTY_BLACKLIST
    delete env[p]

  CURRENT_ENV = env

################################################################################
# Configuration of task configs and aliass
################################################################################
TASK_CONFIG = {}
TASK_ALIAS_MAP = {}
register_task_config = (task_config) ->
  for task_name, config of task_config
    {alias} = config(CURRENT_ENV)
    TASK_ALIAS_MAP[alias] = task_name
  TASK_CONFIG = task_config

get_opts_for_task = (task, env) ->
  util.clone_apply env, TASK_CONFIG[task](env)

GET_ENV = (obj) ->
  env = _.assign {}, process.env, JAVA_HOME: process.env.JAVA8_HOME
  _.assign {}, env, obj

# read a property from a task
# (string, string) -> string
read_task_property = (task, property) ->
  TASK_CONFIG[task](CURRENT_ENV)[property]

# does this task exist?
# (string) -> boolean
task_exists = (task) -> TASK_CONFIG[task]?

# globalish container for running processes
PROCS = {}

print_process_status = (child_id, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  repl_lib.print child_id.cyan, status

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
  repl_lib.print if _.keys(PROCS).length
      ("#{k}\n" for k, v of PROCS).join('')
    else
      'Nothing!'.bold.cyan

repl_lib.add_command
  name: 'ps'
  help: 'status of running processes'
  fn: processes_running

################################################################################
#  Healthcheck
################################################################################
repl_lib.add_command
  name: 'health'
  help: 'healthchecks services'
  fn: (task) ->
    stop_indicator = repl_lib.start_progress_indicator()
    child_process.exec './healthcheck --color=always', (error, stdout, stderr) ->
      stop_indicator()
      repl_lib.print stdout
      if stderr
        repl_lib.print 'error'.red + stderr

    repl_lib.print "Healthchecking #{task || 'all'}"

################################################################################
#  whats-running
################################################################################
repl_lib.add_command
  name: 'whats-running'
  help: 'whats-running shell script'
  fn: (task) ->
    repl_lib.print 'whats-running', '...'
    stop_indicator = repl_lib.start_progress_indicator()
    child_process.exec './whats-running', (error, stdout, stderr) ->
      stop_indicator()
      repl_lib.print stdout
      if stderr
        repl_lib.print stderr.red

################################################################################
#  nuke javas
################################################################################
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

################################################################################
#  Repl Help
################################################################################
repl_help = (args) ->
  repl_lib.print 'available commands'.cyan.bold
  strs = for {name, help, usage, alias} in _.values(repl_lib.get_commands())
    str = "#{name.cyan}: #{help}\n"
    str += "usage: #{usage}\n" if usage
    str += "alias: #{alias}\n" if alias
    str

  repl_lib.print strs.join '\n'

repl_lib.add_command
  name: 'help'
  alias: 'h'
  help: "'help' helps you get help for commands such as 'help'"
  fn: repl_help

################################################################################
#  Start one task
#  Returns a promise
################################################################################
try_to_clone = (repo_name) ->
  deferred = Q.defer()
  repl_lib.print 'Trying to clone...'.magenta
  try
    child = run_cmd(['git', 'clone', "git@github.com:RallySoftware/#{repo_name}.git"], "#{process.env.HOME}/projects", GET_ENV())
  catch e
    repl_lib.print "error cloning repo #{repo_name}".red, e

  child.on 'close', -> deferred.resolve()

  deferred.promise

wait_for_keypress = ->
  deferred = Q.defer()
  process.stdin.once 'data', (char) ->
    process.stdout.clearLine()
    deferred.resolve char
  return deferred.promise

start_task = (task_name, env=CURRENT_ENV) ->
  deferred = Q.defer()

  unless task_name
    return Q()

  task_name = resolve_task_name task_name

  unless TASK_CONFIG[task_name]?
    util.log_error "Task does not exist: #{task_name}"
    return Q()

  env = get_opts_for_task(task_name, env)

  if env.check?
    if !env.check()
      util.log_error "Task #{task_name} failed prestart check"
      return Q()
    else
      util.repl_print "Task #{task_name} passed prestart check".green

  repl_lib.print "Starting #{task_name.cyan}".yellow

  repl_lib.print '$>'.gray.bold, ("#{k}".blue.bold+'='.gray+"#{v}".magenta for k, v of env.additional_env).join(' '), "#{env.command.join(' ')}".green

  if env.start_message
    repl_lib.print env.start_message

  callback = env.callback ? (_, env) -> env

  try
    cwd = env.cwd ? require.main.filename.replace(/\/[\w-_]+$/, '')
    fs.statSync(cwd).isDirectory()
  catch e
    repl_lib.print "You don't have #{task_name}.  Try cloning? [yn]".yellow
    wait_for_keypress().then (char) ->
      if char.toString() is 'y'
        try_to_clone(task_name).then ->
          repl_lib.print 'Cloned!'.green
          deferred.resolve CURRENT_ENV
      else
        repl_lib.print 'Not cloning'.magenta
        deferred.resolve CURRENT_ENV

    # this should work:
    # do run_task with the task you just cloned
    # return THAT promise here
    return deferred.promise

  [cmd, argv...] = env.command

  mproc = mexpect.spawn cmd, argv,
    verbose: false
    env: GET_ENV env.additional_env
    cwd: cwd

  mproc.wait_for_once env.wait_for, (data) ->
    data = env.wait_for.exec?(data) ? [data]
    try
      SET_ENV callback data, env
      deferred.resolve CURRENT_ENV
      repl_lib.print "Started #{env.name}!".green
    catch e
      repl_lib.print "Failed to start #{env.name}!".bold.red, e

  proc = mproc.proc

  proc.on 'error', (err) ->
    msg = switch err.code
      when 'ENOENT' then "File not found"
      when 'EPIPE' then "Writing to closed pipe"
      else err.code

    util.log_error "Error: #{task_name} #{err.code} #{msg}"

  proc.on 'close', (code, signal) ->
    print_process_status task_name, code, signal
    kill_tree proc.pid
    delete PROCS[task_name]

  if _.isFunction(env.onClose)
    proc.on 'close', (code, signal) ->
      repl_lib.print "Running exit commands for #{task_name.cyan}...".yellow
      env.onClose.call env, code, signal

  pipe_to_std_streams = (prefix, task_proc) ->
    prefix = util.get_color_fn()("#{prefix}:")
    util.pipe_with_prefix prefix, task_proc.stdout, process.stdout
    util.pipe_with_prefix prefix, task_proc.stderr, process.stderr

  if env.verbose
    pipe_to_std_streams task_name, proc

  PROCS[task_name] = proc

  deferred.promise

################################################################################
#  Kill task
################################################################################
kill_tree = (pid, signal='SIGKILL') ->
  psTree = require('ps-tree')
  psTree pid, (err, children) ->
    [pid].concat(_.pluck(children, 'PID')).forEach (pid) ->
      try
        process.kill(pid, signal)
      catch e
        # util.error 'Error: Trying to kill', e.stack

kill_task = (task) ->
  deferred = Q.defer()

  task = resolve_task_name task

  proc = PROCS[task]
  if proc
    proc.on 'close', ->
      deferred.resolve()
    kill_tree proc.pid
    repl_lib.print "Killing #{task.red}..."
  else
    repl_lib.print "No proc matching '#{task.cyan}' found"
    deferred.resolve()

  deferred.promise

repl_lib.add_command
  name: 'kill'
  alias: 'k'
  help:'kill a task'
  usage:'kill [TASK]'
  fn: kill_task

kill_running_tasks = ->
  repl_lib.print "Killing all tasks...".yellow
  Q.all _(PROCS).keys().map(kill_task).value()

repl_lib.add_command
  name: 'killall'
  alias: 'ka'
  help:'kill all running processes'
  fn: kill_running_tasks

################################################################################
#  Restart Task
################################################################################
repl_lib.add_command
  name: 'restart'
  alias: 'rs'
  help: 'restart a task'
  usage: 'restart [TASK]'
  fn: (task) ->
    repl_lib.print "Restarting #{task}..."
    kill_task(task).then ->
      start_task(task)

################################################################################
#  Run Tasks
#
# Starts all tasks, waiting until each previous task finishes starting
# before continuing
# TODO:
# play sound when all tasks have run
################################################################################
resolve_task_name = (task) -> TASK_ALIAS_MAP[task] ? task

run_tasks = (tasks, initial_env=CURRENT_ENV) ->
  final = tasks.reduce (previous, task) ->
    previous.then((env) ->
      start_task(task, env)
    , (error) ->
      util.error 'Error handler:', error.stack
    ).fail (error) ->
      util.error 'Fail handler:', error.stack
  , Q initial_env

  final.then ->
    if tasks.length > 0
      repl_lib.print 'Started all tasks!'.bold.green

repl_lib.add_command
  name: 'run'
  alias: 'r'
  help: 'start multiple tasks'
  usage: 'run [TASKS]'
  fn: (tasks...) ->
    run_tasks tasks

################################################################################
# REPL ENV
#
# Print information about your environment
################################################################################
repl_lib.add_command
  name: 'env'
  alias: 'e'
  help: 'print information about your environment'
  fn: ->
    repl_lib.print 'ENV'.cyan.bold
    repl_lib.print ("#{k}".blue.bold+'='.gray+"#{v}".magenta for k, v of CURRENT_ENV).join('\n')

repl_lib.add_command
  name: 'set'
  alias: 's'
  help: 'set environment variable'
  usage: 'set [KEY] [VALUE]'
  fn: (k='', v='') ->
    unless k.length > 0 and v.length > 0
      repl_lib.print this.help.split('\n')[0]
      return

    repl_lib.print 'setting'.cyan.bold, "#{k}".blue.bold, 'to'.cyan.bold, "#{v}".magenta

    v = if v is 'false' then false else v
    v = if v is 'true'  then true  else v

    CURRENT_ENV[k] = v

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
    path = if task_exists(target)
      read_task_property target, 'cwd'
    else if fs.statSync("#{process.env.HOME}/projects/#{target}")?.isDirectory()
      "#{process.env.HOME}/projects/#{target}"
  catch e
    unless e.code is 'ENOENT' # handle missing directory below
      throw e

  unless path?
    repl_lib.print "'#{target}' is not a task name or a directory in ~/projects".red
    return

  run_cmd cmd, path, GET_ENV()

repl_lib.add_command
  name: 'tell'
  alias: 't'
  tab_complete: (args) ->
    ['ronald', 'mc', 'donald']
  help: 'tell someone to do something (e.g. tell alm grunt clean build)'
  usage: 'tell [TASK] [COMMAND]'
  fn: (target, cmd...) ->
    targets = target.split ','
    _.map targets, (target) -> tell_target target, cmd

################################################################################
# tasks
#
# print all tasks
################################################################################
repl_lib.add_command
  name: 'tasks'
  help: 'print all tasks'
  fn: ->
    repl_lib.print 'tasks:', (_(TASK_CONFIG).keys().value().join ' ').cyan

################################################################################
# exit stacker
################################################################################
stacker_exit = (repl) ->
  # max timeout of 4s
  _.delay process.exit, 4000
  kill_running_tasks().then ->
    repl_lib.print 'Killed running tasks!'.green

    t = 0 ; delta = 200 ; words = "Going To Sleep Mode".split(' ')
    _.map words, (word) ->
      setTimeout (-> repl.outputStream.write "#{word.blue.bold} "), t += delta

    _.delay process.exit, words.length * delta

################################################################################
# boot stack
#
# Boots the stack
################################################################################
boot_stack = (tasks, should_start_repl) ->
  repl_lib.print 'VERBOSE MODE'.red if CURRENT_ENV.verbose

  if should_start_repl
    repl_lib.print 'Starting REPL'.bold.green
    repl = repl_lib.start()
    repl.on 'exit', -> stacker_exit repl

  if tasks.length > 0
    repl_lib.print 'running tasks:', tasks.join(' ').cyan


  run_tasks(tasks, CURRENT_ENV)

module.exports =
  start_task: start_task
  run_tasks: run_tasks
  run_cmd: run_cmd
  boot: boot_stack
  register_task_config: register_task_config
  set_env: SET_ENV
  read_task_property: read_task_property