#!/usr/bin/env coffee

colors = require 'colors'
Q = require 'q'
_ = require 'lodash'
nexpect = require 'nexpect'
repl_lib = require './repl'
util = require './util'
child_process = require 'child_process'

{exec} = require 'child_process'

# Commands TODO
# set verbose on and off for a process
# check if everything is set up

##########################################
# Current REPL environment - keeps track of verbose/quiet, using appsdk/churro/whatever
##########################################
CURRENT_ENV = {}
SET_ENV = (env) ->
  unless env?
    throw new Error "You shouldn't null out the ENV.  Make sure to return ENV from your task handlers"

  env = _.cloneDeep env

  # dont save the state of some properties
  for p in ['start_message', 'name', 'alias', 'command', 'wait_for']
    delete env[p]

  CURRENT_ENV = env

##########################################
# Configuration of task configs and aliass
##########################################
TASK_CONFIG = {}
TASK_ALIAS_MAP = {}
register_task_config = (task_config) ->
  for task_name, config of task_config
    {alias} = config(CURRENT_ENV)
    TASK_ALIAS_MAP[alias] = task_name
  TASK_CONFIG = task_config

get_opts_for_task = (task, env) ->
  util.clone_apply env, TASK_CONFIG[task](env)

get_env = (obj) ->
  env = _.assign {}, process.env, JAVA_HOME: process.env.JAVA8_HOME
  _.assign {}, env, obj

# globalish container for running processes
PROCS = {}

##########################################
#  Process Status
#
#  TODO: what cool stuff can we show?
#  - Runtime
#  - PID
#  - Git branch?!
#  - Version #??
##########################################
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

##########################################
#  Healthcheck
#
#  TODO
#  Healthcheck services
##########################################

repl_lib.add_command
  name: 'health'
  help: 'healthchecks services'
  fn: (task) ->
    timer = setInterval((-> process.stdout.write ' . '), 300)
    child_process.exec './healthcheck', (error, stdout, stderr) ->
      clearInterval(timer)
      repl_lib.print stdout
      if stderr
        repl_lib.print 'error'.red + stderr

    repl_lib.print "Healthchecking #{task || 'all'}"

##########################################
#  whats-running
##########################################

repl_lib.add_command
  name: 'whats-running'
  help: 'whats-running shell script'
  fn: (task) ->
    timer = setInterval((-> repl_lib.print 'whats-running', '.'), 300)
    repl_lib.print 'whats-running', '...'
    child_process.exec './whats-running', (error, stdout, stderr) ->
      clearInterval(timer)
      repl_lib.print 'whats-running', line for line in stdout.split('\n')
      if stderr
        repl_lib.print 'whats-running error'.red + stderr

##########################################
#  nuke javas
##########################################

repl_lib.add_command
  name: 'nuke'
  help: 'kill -9 java'
  fn: (task) ->
    child_process.exec 'killall -9 java', (error, stdout, stderr) ->
    PROCS = {}
    repl_lib.print 'Nuking All Javas!'.magenta

##########################################
#  Set
#
# TODO
#
#  Set environment variables
#  available options:
#    verbose [true/false]
#    zk-address
#    burro-address
##########################################
# repl_lib.add_command
#   name: 'set'
#   help: """
# set an an environment variable value
# #{'NOT IMPLEMENTED'.red}
# usage: set [VARIABLE] [VALUE]
# available options:
#   verbose [true/false]
#   zk-address
#   burro-address
#   """
#   fn: (variable, value) -> repl_lib.print "setting '#{variable}' to '#{value}'"

##########################################
#  Repl Help
##########################################
repl_help = (args) ->
  repl_lib.print 'available commands'.cyan.bold
  repl_lib.print ("#{name.cyan}:\t#{help}" for {name, help} in repl_lib.get_commands()).join '\n'

repl_lib.add_command
  name: 'help'
  alias: 'h'
  help: "'help' helps you get help for commands such as 'help'"
  fn: repl_help

##########################################
#  Start one task
#  Returns a promise
##########################################
start_task = (task_name, env=CURRENT_ENV) ->
    deferred = Q.defer()

    unless task_name
      return Q()

    task_name = resolve_task_name task_name

    unless TASK_CONFIG[task_name]?
      util.log_error "Task does not exist: #{task_name}"
      return Q()

    env = get_opts_for_task(task_name, env)

    repl_lib.print "Starting #{task_name.cyan}".yellow

    repl_lib.print '$>'.gray.bold, ("#{k}".blue.bold+'='.gray+"#{v}".magenta for k, v of env.additional_env).join(' '), "#{env.command.join(' ')}".green

    if env.start_message
      repl_lib.print env.start_message

    callback = env.callback ? (_, env) -> env

    proc = nexpect.spawn(env.command, [],
      stream: 'all'
      verbose: false
      env: get_env env.additional_env
      cwd: env.cwd ? require.main.filename.replace(/\/[\w-_]+$/, ''))
    .wait env.wait_for, (data) ->
      data = env.wait_for.exec?(data) ? [data]
      try
        SET_ENV callback data, env
        deferred.resolve CURRENT_ENV
        repl_lib.print "Started #{env.name}!".green
      catch e
        repl_lib.print "Failed to start #{env.name}!".bold.red, e

    proc = proc.run (err) ->
      if err
        repl_lib.print ("Error running task #{task_name}: " + (err.message ? err)).red
        kill_tree PROCS[task_name]
        delete PROCS[task_name]

    pipe_to_std_streams = (task_proc, prefix) ->
      prefix = util.get_color_fn()("#{prefix}:")
      util.pipe_with_prefix prefix, task_proc.stdout, process.stdout
      util.pipe_with_prefix prefix, task_proc.stderr, process.stderr

    if env.verbose
      pipe_to_std_streams proc, task_name

    PROCS[task_name] = proc

    deferred.promise

##########################################
#  Kill task
##########################################
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
    proc.on 'error', (a,b,c) -> repl_lib.print "error sending signal to #{task.cyan}",a,b,c
    proc.on 'close', (code, signal) ->
      repl_lib.print "Killed #{task.cyan}:", signal
      delete PROCS[task]
      deferred.resolve()
    kill_tree proc.pid
    repl_lib.print "Killing #{task.red}..."
  else
    repl_lib.print "No proc matching '#{task.cyan}' found"
    deferred.resolve()

  deferred.promise

kill_running_tasks = ->
  repl_lib.print "Killing all tasks..."
  Q.all _(PROCS).keys().map(kill_task).value()

repl_lib.add_command
  name: 'kill'
  alias: 'k'
  help:'usage: kill [TASK]\n\tkill a task\n\talias: k'
  fn: kill_task

##########################################
#  Restart Task
##########################################
repl_lib.add_command
  name: 'restart'
  alias: 'rs'
  help: 'usage: restart [TASK]\n\trestart a task\n\talias: rs'
  fn: (task) ->
    repl_lib.print "Restarting #{task}..."
    kill_task(task).then ->
      start_task(task)

##########################################
#  Run Tasks
#
# Starts all tasks, waiting until each previous task finishes starting
# before continuing
# TODO:
# play sound when all tasks have run
##########################################
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
  help: 'usage: run [TASKS]\n\tstart multiple tasks\n\talias: r'
  fn: (tasks...) ->
    run_tasks tasks

##########################################
# REPL ENV
#
# Print information about your environment
##########################################
repl_lib.add_command
  name: 'env'
  alias: 'e'
  help: 'usage: env\n\tprint information about your environment\n\talias: e'
  fn: ->
    repl_lib.print 'ENV'.cyan.bold
    repl_lib.print ("#{k}".blue.bold+'='.gray+"#{v}".magenta for k, v of CURRENT_ENV).join('\n')

repl_lib.add_command
  name: 'set'
  alias: 's'
  help: 'usage: set [KEY] [VALUE]\n\tset environment variable\n\talias: s'
  fn: (k='', v='') ->
    unless k.length > 0 and v.length > 0
      repl_lib.print this.help.split('\n')[0]
      return

    repl_lib.print 'setting'.cyan.bold, "#{k}".blue.bold, 'to'.cyan.bold, "#{v}".magenta

    v = if v is 'false' then false else v
    v = if v is 'true'  then true  else v

    CURRENT_ENV[k] = v

##########################################
# REPL TELL
#
# Print information about your environment
##########################################
repl_lib.add_command
  name: 'tell'
  alias: 't'
  help: 'usage: tell [TASK] [COMMAND]\n\ttell someone to do something (e.g. tell alm grunt clean build)\n\talias: t'
  fn: (target, cmd...) ->

    util.pipe_with_prefix ''

    console.log 'doing tell', target
    console.log 'cmd', cmd

    # get cwd
    # exec in that cwd

##########################################
# boot stack
#
# Boots the stack
##########################################

boot_stack = (tasks) ->
  repl_lib.print 'VERBOSE MODE'.red if CURRENT_ENV.verbose
  if tasks.length > 0
    repl_lib.print 'running tasks:', tasks.join(' ').cyan
  else
    repl_lib.print 'Starting REPL'.bold.green

  repl = repl_lib.start()

  # TODO: kill all running processes on exit
  repl.on 'exit', ->
    # max timeout of 4s
    _.delay process.exit, 4000

    kill_running_tasks().then ->
      repl_lib.print 'killed running tasks'

      t = 0 ; delta = 200 ; words = "Going To Sleep Mode".split(' ')
      _.map words, (word) ->
        setTimeout (-> repl.outputStream.write "#{word.blue.bold} "), t += delta

      _.delay process.exit, words.length * delta

  run_tasks(tasks, CURRENT_ENV)

module.exports =
  start_task: start_task
  run_tasks: run_tasks
  boot: boot_stack
  register_task_config: register_task_config
  set_env: SET_ENV