_ = require 'lodash'
util = require '../util/util'

# configDir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/.stacker"

# Set this to rally-stack for now
configDir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/projects/rally-stack/stacker/config"

module.exports = _.memoize ->
  config = {}
  try
    config = require("#{configDir}/config.coffee")
    util.repl_print "Using config dir: #{configDir.cyan}"
  catch e
    util.repl_print "No config file found".red, "#{configDir}/config.coffee"
    # console.log e
  config
