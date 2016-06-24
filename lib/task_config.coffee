fs = require 'fs'
_ = require 'lodash'
util = require './util'
config = require './config_lib'
state_lib = require './state_lib'
exported_util = require './exported_util'
_log = (args...) -> util.debug_log.apply null, [__filename].concat args

################################################################################
# Configuration of task configs and aliass
################################################################################
REGISTERED = false
TASK_CONFIG = {}
TASK_ALIAS_MAP = {}

require_task_config = _.memoize ->
  task_dir = "#{config.get_config_dir()}/tasks"

  task_config = {}

  try
    for file in fs.readdirSync(task_dir, ->) when fs.statSync("#{task_dir}/#{file}").isFile()
      _log "requiring task file #{task_dir}/#{file}"
      task_config[file.replace(/\.coffee$/, '')] = require "#{task_dir}/#{file}"
  catch e

  task_config

register_task_config = ->
  task_config = require_task_config()
  for task_name, config of task_config
    {alias} = config(state_lib.get_stacker_state(), exported_util)
    TASK_ALIAS_MAP[alias] = task_name
  TASK_CONFIG = task_config

get_task_config = (task) ->
  register_task_config() unless REGISTERED
  config = TASK_CONFIG[task]
  config?(state_lib.get_stacker_state(), exported_util) ? config

get_task_configs = ->
  register_task_config() unless REGISTERED
  util.object_map TASK_CONFIG, (task, config) ->
    "#{task}": get_task_config task

# read a property from a task
# (string, string) -> string
read_task_property = (task, property) ->
  get_task_config(task)[property]

# does this task exist?
# (string) -> boolean
task_exists = (task) ->
  register_task_config() unless REGISTERED
  TASK_CONFIG[task]?

resolve_task_name = (task) ->
  register_task_config() unless REGISTERED
  TASK_ALIAS_MAP[task] ? task

get_task_config_map = -> TASK_CONFIG

exports = {
  task_exists
  resolve_task_name
  read_task_property
  register_task_config
  get_task_config
  get_task_configs
  get_task_config_map
}

module.exports[k] = v for k, v of exports
