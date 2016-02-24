_ = require 'lodash'

################################################################################
# Current REPL environment - keeps track of verbose/quiet, using appsdk/churro/whatever
################################################################################
CURRENT_ENV = {}

set_stacker_env = (env = CURRENT_ENV) ->
  CURRENT_ENV = _.cloneDeep env

get_shell_env = (obj) ->
  env = _.assign {}, process.env, JAVA_HOME: process.env.JAVA8_HOME
  _.assign {}, env, obj

module.exports =
  get_shell_env: get_shell_env
  get_stacker_env: -> CURRENT_ENV
  set_stacker_env: set_stacker_env
