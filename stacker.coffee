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
# if task_name is passed in, will prefix output with that
# ({cmd: [string], task_name: string, cwd: string, env: map, silent: boolean, pipe_output: boolean}) -> child_process
run_cmd = ({cmd, task_name, cwd, env, silent, pipe_output}) ->
  cwd ?= process.cwd()
  env ?= GET_ENV()
  silent ?= false
  pipe_output ?= true

  proc = child_process.spawn 'zsh', [],
    cwd: cwd
    env: env

  proc.stdin.write(ZSHMIN + '\n')
  proc.stdin.write(cmd.join(' ') + '\n')
  proc.stdin.end()

  stop_indicator = repl_lib.start_progress_indicator()
  proc.stdout.on 'readable', stop_indicator
  proc.stdout.on 'data', stop_indicator
  proc.stderr.on 'readable', stop_indicator
  proc.stderr.on 'data', stop_indicator

  child_id = task_name ? "#{util.regex_extract(/\/([\w-]+)$/, cwd)}-#{cmd.join('-')}-#{proc.pid}"

  proc.on 'close', (exit_code, signal) ->
    delete PROCS[child_id]

  PROCS[child_id] = proc

  if pipe_output
    prefix = util.get_color_fn()("#{child_id}:")
    util.pipe_with_prefix prefix, proc.stdout, process.stdout
    util.pipe_with_prefix prefix, proc.stderr, process.stderr

  unless silent
    proc.on 'close', (exit_code, signal) ->
      print_process_status child_id, exit_code, signal

    repl_lib.print '$>'.gray, "#{'cd'.green} #{cwd.cyan}#{';'.green}", "#{cmd.join(' ')}".green

  proc

################################################################################
# Current REPL environment - keeps track of verbose/quiet, using appsdk/churro/whatever
################################################################################
CURRENT_ENV = {}

ENV_PROPERTY_BLACKLIST = [
  'start_message'
  'name'
  'alias'
  'command'
  'wait_for'
  'callback'
  'additional_env'
  'cwd'
  'check'
  'onClose'
  'daemon'
]

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

GET_OPTS_FOR_TASK = (task, env) ->
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

# container for running processes
PROCS = {}

# container to keep track of tasks that run in the background
DAEMONS = {}

print_process_status = (name, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  repl_lib.print name.cyan, status

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
    'No running procs!'.bold.cyan


  repl_lib.print if _.keys(DAEMONS).length
    "\n#{'Daemons'.cyan}\n#{("#{k}\n" for k, v of DAEMONS).join('')}"
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

    repl_lib.print if _.keys(DAEMONS).length
      "#{("#{k}\n" for k, v of DAEMONS).join('')}"
    else
      'No running daemons!'.bold.cyan

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

############ cloning shit ############
try_to_clone = (task_name, repo_name) ->
  deferred = Q.defer()
  promise = deferred.promise

  repl_lib.print "You don't have #{repo_name}.  Try cloning? [yn]".yellow
  wait_for_keypress().then (char) ->
    repl_lib.clear_line()
    if char.toString() is 'y'
      repl_lib.print 'Trying to clone...'.magenta
      try
        child = run_cmd
          cmd: ['git', 'clone', "git@github.com:RallySoftware/#{repo_name}.git"]
          cwd: "#{process.env.HOME}/projects"
          env: GET_ENV()
      catch e
        repl_lib.print "error cloning repo #{repo_name}".red, e

      child.on 'close', ->
        repl_lib.print 'Cloned!'.green
        deferred.resolve CURRENT_ENV
        promise = start_task task_name, GET_OPTS_FOR_TASK(task_name, CURRENT_ENV)

    else
      repl_lib.print 'Not cloning'.magenta
      deferred.resolve CURRENT_ENV

  promise


wait_for_keypress = ->
  deferred = Q.defer()
  process.stdin.once 'data', (char) ->
    process.stdout.clearLine()
    deferred.resolve char
  deferred.promise
############ / cloning shit ############

start_foreground_task = (task_name, env, cwd, callback) ->
  [cmd, argv...] = env.command

  deferred = Q.defer()

  mproc = mexpect.spawn cmd, argv,
    verbose: false
    env: GET_ENV env.additional_env
    cwd: cwd

  mproc.wait_for_once env.wait_for, (data) ->
    data = env.wait_for.exec?(data) ? [data]
    try
      new_env = callback data, env
      deferred.resolve [mproc.proc, new_env]
      repl_lib.print "Started #{env.name}!".green
    catch e
      repl_lib.print "Failed to start #{env.name}!".bold.red, e

  proc = mproc.proc

  PROCS[task_name] = proc

  util.prefix_pipe_output task_name, mproc.proc

  proc.on 'close', (code, signal) ->
    print_process_status task_name, code, signal
    kill_tree proc.pid
    delete PROCS[task_name]

  if _.isFunction(env.onClose)
    proc.on 'close', (code, signal) ->
      repl_lib.print "Running exit commands for #{task_name.cyan}...".yellow
      env.onClose.call env, code, signal

  deferred.promise

# ({}, '', fn) -> Promise -> proc, new_env, code, signal
start_wait_for_daemon = (env, cwd, callback) ->
  [cmd, argv...] = env.command
  wait_for_deferred = Q.defer()

  mproc = mexpect.spawn cmd, argv,
    verbose: false
    env: GET_ENV env.additional_env
    cwd: cwd

  mproc.wait_for_once env.wait_for, (data) ->
    data = env.wait_for.exec?(data) ? [data]
    try
      new_env = callback(data, env) # throws
      repl_lib.print "Started #{env.name}!".green
      wait_for_deferred.resolve new_env
    catch e
      repl_lib.print "Failed to start #{env.name}!".bold.red, e
      wait_for_deferred.resolve CURRENT_ENV

  util.prefix_pipe_output "start-#{env.name}", mproc.proc

  proc_deferred = Q.defer()
  mproc.proc.on 'close', (code, signal) ->
    proc_deferred.resolve [code, signal]

  mproc.proc.on 'error', util.log_proc_error

  proc_deferred.promise.then ([code, signal]) ->

    unless code is 0
      throw 'Error! non zero exit code starting daemon ' + task_name

    unless wait_for_deferred.promise.inspect().state is 'fulfilled'
      throw 'Error!'

    wait_for_deferred.promise.then (new_env) ->
      [mproc.proc, new_env, code, signal]

  .fail (err) ->
    console.log 'start wait for daemon ERROR!', err.stack

# ({}, '', fn) -> Promise -> proc, new_env, code, signal
start_standard_daemon = (env, cwd, callback) ->
  [cmd, argv...] = env.command

  deferred = Q.defer()

  proc = child_process.spawn cmd, argv,
    env: GET_ENV env.additional_env
    cwd: cwd

  PROCS[task_name] = proc

  util.pipe_with_prefix "start-#{env.name}", proc

  proc.on 'close', (code, signal) ->
    try
      new_env = callback(data, env) # throws
      repl_lib.print "Started #{env.name}!".green # figure out how to move this back to start_daemon_task
      delete PROCS[task_name]
    catch e
      new_env = CURRENT_ENV
      repl_lib.print "Failed to start #{env.name}!".bold.red, e

    deferred.resolve [proc, new_env, code, signal]

  proc.on 'error', util.log_proc_error

    # kill_tree proc.pid # check if this is needed / works

  deferred.promise

start_daemon_task = (task_name, env, cwd, callback) ->
  [cmd, argv...] = env.command

  promise = if env.wait_for?
    start_wait_for_daemon env, cwd, callback
  else
    start_standard_daemon env, cwd, callback

  promise.then (results) ->
    [proc, new_env, code, signal] = results

    SET_ENV env

    # print_process_status "start-#{task_name}", code, signal

    DAEMONS[task_name] = env

    delete PROCS[task_name]

    [proc, new_env, code, signal]
  .fail (err) ->
    console.log '%%%%%%%%%%%%%%%%%%%', err.stack

start_task = (task_name, env=CURRENT_ENV) ->
  deferred = Q.defer()

  unless task_name
    return Q()

  task_name = RESOLVE_TASK_NAME task_name

  unless TASK_CONFIG[task_name]?
    util.log_error "Task does not exist: #{task_name}"
    return Q()

  env = GET_OPTS_FOR_TASK(task_name, env)

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

  try # maybe clone repo hey why not
    cwd = env.cwd ? require.main.filename.replace(/\/[\w\-_]+$/, '')
    fs.statSync(cwd).isDirectory()
  catch e
    repo_name = env.cwd.replace(/.*\/([\w\-_]+)$/, '$1')
    return try_to_clone task_name, repo_name

  promise = if env.exit_command?
    start_daemon_task task_name, env, cwd, callback
  else
    start_foreground_task task_name, env, cwd, callback

  promise.then ([proc, new_env, code, signal]) ->
    deferred.resolve new_env
  .fail (err) ->
    console.log 'starttask fail', err, err.stack


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

kill_daemon_task = (task_name, daemon) ->
  deferred = Q.defer()

  repl_lib.print "Running exit command for #{task_name.cyan}...".yellow

  kill_proc = run_cmd
    task_name: task_name
    cmd: daemon.exit_command
    env: daemon

  kill_proc.on 'close', (exit_code, signal) ->
    print_process_status task_name, exit_code, signal
    delete DAEMONS[task_name]

  deferred.promise

kill_foreground_task = (task_name, proc) ->
  deferred = Q.defer()

  proc.on 'close', ->
    deferred.resolve()

  kill_tree proc.pid
  repl_lib.print "Killing #{task_name.red}..."

  deferred.promise

kill_task = (task_name) ->
  deferred = Q.defer()

  task_name = RESOLVE_TASK_NAME task_name

  proc = PROCS[task_name]
  daemon = DAEMONS[task_name]

  unless proc or daemon
    repl_lib.print "No process or daemon matching '#{task_name.cyan}' found"
    return deferred.resolve()

  if proc
    proc_promise = kill_foreground_task task_name, proc

  if daemon
    daemon_promise = kill_daemon_task task_name, daemon

  Q.all(_.compact([proc_promise, daemon_promise]))

repl_lib.add_command
  name: 'kill'
  alias: 'k'
  help:'kill a task'
  usage:'kill [TASK]'
  fn: kill_task

kill_running_tasks = ->
  repl_lib.print "Killing all tasks...".yellow
  Q.all _(DAEMONS).keys().map(kill_task).value()
  .then ->
    _(PROCS).keys().map(kill_task).value()

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
#
################################################################################
RESOLVE_TASK_NAME = (task) -> TASK_ALIAS_MAP[task] ? task

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
      repl_lib.print @help.split('\n')[0]
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

  run_cmd {cmd, cwd: path, env: GET_ENV()}

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

    t = 0 ; delta = 200 ; words = "Going To Sleep Mode".split ' '
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