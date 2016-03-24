_ = require 'lodash'
util = require '../util/util'

# configDir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/.stacker"

# Set this to rally-stack for now
config_dir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/projects/rally-stack/stacker/config"

module.exports =
  get_config_dir: -> config_dir

  get_config: _.memoize ->
    config = {}
    try
      config = require("#{config_dir}/config.coffee")
      util.repl_print "Using config dir: #{config_dir.cyan}"
    catch e
      util.repl_print "No config file found".red, "#{config_dir}/config.coffee"
      # console.log e
    config
