module.exports = (env) ->
  name: 'Test Daemon'
  alias: 'aod'
  command: ['echo', 'Started all the test infrastructures!!']
  exit_command: ['echo', 'Shutting all the shit down!']
  is_running: -> Promise.resolve true
  cleanup: ->
    repl_lib.print 'Cleaning things up!  For serious'.yellow
    run_cmd
      cmd: ['echo', 'Cleaning up after test daemon...']
    .on_close
  cwd: "#{env.ROOTDIR}/rally-stack/stacker/etc"
  start_message: 'daemon is always running'
  onClose: (code, signal) ->
    run_cmd cmd: ['echo', 'Exit command run!']