_ = require 'lodash'
exported_util = require './exported_util'
util = require './util'
_log = (args...) -> util.debug_log.apply null, [__filename].concat args

config_dir = process.env.STACKER_CONFIG_DIR ? "#{process.env.HOME}/.stacker"
config_file = "#{config_dir}/config.coffee"

exports =
  get_config_dir: -> config_dir

  get_config_file: -> config_file

  get_config: _.memoize ->
    config = {}
    try
      _log "requiring config file #{config_file}"
      config = require config_file
    catch e
      _log e
    config?(exported_util) ? config

module.exports[k] = v for k, v of exports
