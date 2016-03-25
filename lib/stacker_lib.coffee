#!/usr/bin/env coffee

require 'colors'
_ = require 'lodash'
fs = require 'fs'
repl_lib = require './repl_lib'
require '../repl_commands'
env_lib = require './env_lib'
task_config_lib = require './task_config_lib'
task_lib = require './task_lib'
config = require './config_lib'
util = require '../util/util'

################################################################################
# exit stacker
################################################################################
stacker_exit = (repl) ->
  # max timeout of 4s
  _.delay process.exit, 4000
  task_lib.kill_running_tasks().then ->
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
check_config = ->
  config_dir = config.get_config_dir()
  config_file = config.get_config_file()
  try
    fs.stat(config_dir)
    repl_lib.print "Using config dir: #{config_dir.cyan}"

    try
      fs.stat("#{config_dir}/config.coffee")
      repl_lib.print "Using config file: #{config_file.cyan}"
    catch

  catch e
    util._log e
    repl_lib.print "No config found. Using:".yellow, config_dir.cyan

boot_stack = (tasks, should_start_repl) ->
  repl_lib.print 'DEBUG MODE ENABLED'.red if util.get_debug()
  check_config()
  repl_lib.print 'IGNORE RUNNING DAEMONS: ON'.yellow if env_lib.get_stacker_env().ignore_running_daemons

  if should_start_repl
    repl_lib.print 'Starting REPL'.bold.green
    repl = repl_lib.start()
    repl.on 'exit', -> stacker_exit repl

  if tasks.length > 0
    repl_lib.print 'running tasks:', tasks.join(' ').cyan

  task_lib.run_tasks tasks, env_lib.get_stacker_env()

module.exports =
  boot: boot_stack
  register_task_config: task_config_lib.register_task_config
  initialize_env: env_lib.set_stacker_env
