_ = require 'lodash'
config = require('./config_lib').get_config()

################################################################################
# Current REPL environment - keeps track of internal state
################################################################################
CURRENT_STATE = {}

set_stacker_state = (state = CURRENT_STATE) ->
  CURRENT_STATE = _.cloneDeep state

get_stacker_state = -> CURRENT_STATE

get_shell_env = (obj) ->
  _.assign {}, process.env, obj

exports = {
  get_shell_env
  get_stacker_state
  set_stacker_state
}

module.exports[k] = v for k, v of exports
