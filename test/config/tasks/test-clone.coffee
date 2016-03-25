module.exports = (state) ->
  name: 'Test Clone'
  alias: 'tc'
  command: ['echo', 'Started all the test infrastructures!!']
  exit_command: ['rm', '-rf', "#{state.ROOTDIR}/ops-dashboard"]
  cwd: "#{state.ROOTDIR}/ops-dashboard"
  start_message: 'test daemon procs'
  onClose: (code, signal) ->
    run_cmd cmd: ['echo', 'Exit command run!']
