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

TASK_CONFIG = {}
TASK_ALIAS_MAP = {}
register_task_config = (task_config) ->
  TASK_ALIAS_MAP[alias] = name for {alias, name} in task_config
  TASK_CONFIG = task_config

CURRENT_ENV = {}
set_env = (initial_env) -> CURRENT_ENV = initial_env

get_opts_for_task = (task, env) ->
  util.clone_apply env, TASK_CONFIG[task](env)

get_env = (obj) ->
  env = _.assign {}, process.env, JAVA_HOME: process.env.JAVA8_HOME
  _.assign {}, env, obj

# globalish container for running processes
PROCS = {}

prefix_out = (prefix, str...) ->
  str.splice(0,0,'stacker:'.bgWhite.black)
  console.log.apply this, str

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
  console.log "What's running".cyan
  console.log if _.keys(PROCS).length
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
      console.log stdout
      if stderr
        console.log 'error'.red + stderr

    console.log "Healthchecking #{task || 'all'}"

##########################################
#  whats-running
##########################################

repl_lib.add_command
  name: 'whats-running'
  help: 'whats-running shell script'
  fn: (task) ->
    timer = setInterval((-> prefix_out 'whats-running', '.'), 300)
    prefix_out 'whats-running', '...'
    child_process.exec './whats-running', (error, stdout, stderr) ->
      clearInterval(timer)
      prefix_out 'whats-running', line for line in stdout.split('\n')
      if stderr
        console.log 'whats-running error'.red + stderr

##########################################
#  nuke javas
##########################################

repl_lib.add_command
  name: 'nuke'
  help: 'kill -9 java'
  fn: (task) ->
    child_process.exec 'killall -9 java', (error, stdout, stderr) ->
    PROCS = {}
    console.log 'Nuking All Javas!'.magenta

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
#   fn: (variable, value) -> console.log "setting '#{variable}' to '#{value}'"

##########################################
#  Repl Help
##########################################
repl_help = (args) ->
  console.log 'available commands'.cyan.bold
  console.log ("#{name.cyan}:\t#{help}" for {name, help} in repl_lib.get_commands()).join '\n'

repl_lib.add_command
  name: 'help'
  alias: 'h'
  help: "'help' helps you get help for commands such as 'help'"
  fn: repl_help

##########################################
#  Start one task
#  Returns a promise
##########################################)

clrs = [
  ((s) -> s.bgMagenta.black),
  ((s) -> s.bgCyan.black),
  ((s) -> s.bgGreen.black),
  ((s) -> s.bgBlue),
  ((s) -> s.bgYellow.black),
  ((s) -> s.bgRed),
]
clr_idx = 0
get_color_fn = -> clrs[clr_idx++ % clrs.length]

# stream transform
stream = require 'stream'
create_stream_transformer = (output_color_fn, task) ->
  liner = new stream.Transform()
  liner._transform = (chunk, encoding, done) ->
    data = chunk.toString()
    if @_lastLineData
      data = @_lastLineData + data

    lines = data.split('\n')
    @_lastLineData = lines.pop()

    for line in lines
      @push output_color_fn("#{task}:") + ' ' + line + '\n'

    done()

  liner._flush = (done) ->
    if @_lastLineData?
      @push @_lastLineData
    @_lastLineData = null
    done()

  liner

start_task = (task_name, env=CURRENT_ENV) ->
    deferred = Q.defer()

    unless task_name
      return Q()

    unless TASK_CONFIG[task_name]?
      util.log_error "Task does not exist: #{task_name}"
      return Q()

    env = get_opts_for_task(task_name, env)

    if env.start_message
      console.log '\n' + env.start_message.yellow, 'Doing ', "[ #{env.command.join(' ')} ]".green

    proc = nexpect.spawn(env.command, [],
      stream: 'all'
      verbose: false
      env: get_env env.additional_env
      cwd: env.cwd ? require.main.filename.replace(/\/[\w-_]+$/, ''))
    .wait env.wait_for, (data) ->
      data = env.wait_for.exec?(data) ? [data]
      try
        CURRENT_ENV = env.callback data, env
        deferred.resolve CURRENT_ENV
        console.log "Started #{env.name}!".green
      catch e
        console.log "Failed to start #{env.name}!".bold.red

    proc = proc.run (err) ->
      if err
        console.log ("Error running task #{task_name}: " + (err.message ? err)).red
        kill_tree PROCS[task_name]
        delete PROCS[task_name]

    output_color_fn = get_color_fn()
    # initial_print = true

    pipe_output = (task_proc) ->
      task_proc.stdout.pipe(create_stream_transformer(output_color_fn, task_name)).pipe(process.stdout)
      task_proc.stderr.pipe(create_stream_transformer(output_color_fn, task_name)).pipe(process.stderr)

    unless env.quiet
      pipe_output(proc)

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

  proc = PROCS[task]
  if proc
    proc.on 'error', (a,b,c) -> console.log "error sending signal to #{task.cyan}",a,b,c
    proc.on 'close', (code, signal) ->
      console.log "Killed #{task.cyan}:", signal
      delete PROCS[task]
      deferred.resolve()
    kill_tree proc.pid
    console.log "Killing #{task.red}..."
    deferred.promise
  else
    console.log "No proc matching '#{task.cyan}' found"
    deferred.resolve()


kill_running_tasks = ->
  console.log "Killing all tasks..."
  Q.all _(PROCS).keys().map(kill_task).value()

repl_lib.add_command
  name: 'kill'
  alias: 'k'
  help:'usage: kill [TASK]\n\tkill a task\n\talias: k'
  fn: kill_task

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
      task_name = resolve_task_name task
      start_task(task_name, env)
    , (error) ->
      util.error 'Error handler:', error.stack
    ).fail (error) ->
      util.error 'Fail handler:', error.stack
  , Q initial_env

  final.then ->
    if tasks.length > 0
      console.log 'Started all tasks!'.bold.green

repl_lib.add_command
  name: 'run'
  alias: 'r'
  help: 'usage: run [TASKS]\n\tstart multiple tasks\n\talias: r'
  fn: (tasks...) ->
    run_tasks tasks

##########################################
# boot stack
#
# Boots the stack
##########################################

boot_stack = (tasks) ->
  console.log 'VERBOSE MODE'.red if CURRENT_ENV.verbose
  if tasks.length > 0
    console.log 'running tasks:', tasks.join(' ').cyan
  else
    console.log 'Starting REPL'.bold.green

  repl = repl_lib.start()

  # TODO: kill all running processes on exit
  repl.on 'exit', ->
    # max timeout of 4s
    _.delay process.exit, 4000

    kill_running_tasks().then ->
      console.log 'killed running tasks'

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
  set_env: set_env