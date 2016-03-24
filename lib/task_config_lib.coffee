env_lib = require './env_lib'

################################################################################
# Configuration of task configs and aliass
################################################################################
TASK_CONFIG = {}
TASK_ALIAS_MAP = {}

register_task_config = (task_config) ->
  for task_name, config of task_config
    {alias} = config(env_lib.get_stacker_env())
    TASK_ALIAS_MAP[alias] = task_name
  TASK_CONFIG = task_config

GET_OPTS_FOR_TASK = (task) ->
  TASK_CONFIG[task](env_lib.get_stacker_env())

# read a property from a task
# (string, string) -> string
read_task_property = (task, property) ->
  TASK_CONFIG[task](env_lib.get_stacker_env())[property]

# does this task exist?
# (string) -> boolean
task_exists = (task) ->
  TASK_CONFIG[task]?

RESOLVE_TASK_NAME = (task) ->
  TASK_ALIAS_MAP[task] ? task

module.exports =
  task_exists: task_exists
  resolve_task_name: RESOLVE_TASK_NAME
  read_task_property: read_task_property
  register_task_config: register_task_config
  get_task_config: GET_OPTS_FOR_TASK
  get_task_config_map: -> TASK_CONFIG
