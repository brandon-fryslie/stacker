_ = require 'lodash'
util = require './util'

config_dir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/.stacker"
config_file = "#{config_dir}/config.coffee"

module.exports =
  get_config_dir: -> config_dir

  get_config_file: -> config_file

  get_config: _.memoize ->
    config = {}
    try
      util._log __filename, "requiring config file #{config_file}"
      config = require(config_file)
    catch e
      console.log 'got an exception!', e.stack
      util._log __filename, e
    config
