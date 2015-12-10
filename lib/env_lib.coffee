_ = require 'lodash'

################################################################################
# Current REPL environment - keeps track of verbose/quiet, using appsdk/churro/whatever
################################################################################
CURRENT_ENV = {}

SET_ENV = (env = CURRENT_ENV) ->
  CURRENT_ENV = _.cloneDeep env

GET_ENV = (obj) ->
  env = _.assign {}, process.env, JAVA_HOME: process.env.JAVA8_HOME
  _.assign {}, env, obj

module.exports =
  get_shell_env: GET_ENV
  get_env: -> CURRENT_ENV
  set_env: SET_ENV