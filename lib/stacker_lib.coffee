#!/usr/bin/env coffee

require 'colors'
_ = require 'lodash'
fs = require 'fs'
util = require './util'
{args} = require './arg_lib' # require first to setup debug mode
config = require './config_lib'
repl_commands = require './repl_commands'
state_lib = require './state_lib'
task_config_lib = require './task_config'
task_lib = require './task_lib'
_log = (args...) -> util.debug_log.apply null, [__filename].concat args

################################################################################
# boot stack
#
# Boots the stack
################################################################################
check_config = ->
  config_dir = config.get_config_dir()
  config_file = config.get_config_file()
  try
    fs.statSync(config_dir)
    util.print "Using config dir: #{config_dir.cyan}"

    try
      fs.statSync("#{config_dir}/config.coffee")
      util.print "Using config file: #{config_file.cyan}"
    catch

  catch e
    _log e
    util.print 'No config found. Using:'.yellow, config_dir.cyan

boot_stack = ->
  should_start_repl = args.repl

  state_lib.set_stacker_state args.stacker_state

  util.print 'DEBUG MODE ENABLED'.red if util.get_debug()
  check_config()
  util.print 'IGNORE RUNNING DAEMONS: ON'.yellow if state_lib.get_stacker_state().ignore_running_daemons

  if should_start_repl
    util.print 'Starting REPL'.bold.green
    repl_commands.start_repl()

  # get tasks_to_start
  tasks = _.map args._, task_config_lib.resolve_task_name

  if tasks.length > 0
    util.print 'running tasks:', tasks.join(' ').cyan

  task_lib.run_tasks tasks, state_lib.get_stacker_state()

exports =
  boot: boot_stack

module.exports[k] = v for k, v of exports
