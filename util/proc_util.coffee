repl_lib = require '../lib/repl_lib'

print_process_status = (name, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  repl_lib.print name.cyan, status

module.exports = {
  print_process_status
}
