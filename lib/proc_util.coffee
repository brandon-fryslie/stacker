_ = require 'lodash'
util = require './util'

print_process_status = (name, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  util.print name.cyan, status

# Int, Str -> ?
kill_tree = (pid, signal='SIGKILL') ->
  psTree = require('ps-tree')
  psTree pid, (err, children) ->
    [pid].concat(_.map(children, 'PID')).forEach (pid) ->
      try
        process.kill(pid, signal)
      catch e
        if e.code isnt 'ESRCH'
          throw e


module.exports = {
  print_process_status
  kill_tree
}
