util = require './util/util'
repl_lib = require './lib/repl_lib'
_ = require 'lodash'
fs = require 'fs'
config = require './lib/config_lib'
{run_cmd} = require './lib/task_lib'

get_task_config = _.memoize ->
  task_dir = "#{config.get_config_dir()}/tasks"

  task_config = {}
  for file in fs.readdirSync(task_dir) when fs.statSync("#{task_dir}/#{file}").isFile()
    task_config[file.replace(/\.coffee$/, '')] = require "#{task_dir}/#{file}"
    
  task_config

module.exports = {
  get_task_config
}
