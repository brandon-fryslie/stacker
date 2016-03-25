module.exports = (state) ->
  name: 'Test Daemon'
  alias: 'td'
  command: ['echo', 'Started all the test infrastructures!!']
  exit_command: ['echo', 'Shutting all the shit down!']
  is_running: -> Promise.resolve false
  cleanup: ->
    util.print 'Cleaning things up!  For serious'.yellow
    run_cmd
      cmd: ['echo', 'Cleaning up after test daemon...']
    .on_close
  cwd: "#{state.ROOTDIR}/rally-stack/stacker/etc"
  start_message: 'test daemon procs'
  onClose: (code, signal) ->
    run_cmd cmd: ['echo', 'Exit command run!']
