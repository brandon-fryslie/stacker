_ = require 'lodash'
config = require('./config').get_config()

################################################################################
# Current REPL environment - keeps track of internal state
################################################################################
CURRENT_ENV = {}

set_stacker_env = (env = CURRENT_ENV) ->
  CURRENT_ENV = _.cloneDeep env

get_stacker_env = -> CURRENT_ENV

get_shell_env = (obj) ->
  _.assign {}, process.env, obj

module.exports =
  get_shell_env: get_shell_env
  get_stacker_env: get_stacker_env
  set_stacker_env: set_stacker_env
