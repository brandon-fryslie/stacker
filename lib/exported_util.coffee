_ = require 'lodash'
{print} = require './util'
run_cmd = require('./run_cmd')

# A little utility object to inject into the stacker config and the task configs
module.exports = {
  _
  run_cmd
  print
}
