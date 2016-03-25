util = require './util'

print_process_status = (name, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  util.repl_print name.cyan, status

module.exports = {
  print_process_status
}
