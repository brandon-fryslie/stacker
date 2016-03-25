module.exports = (state) ->
  name: 'Fail Daemon'
  alias: 'fd'
  command: ["echo some stuff"]
  wait_for: /Neva gonna happen/
  exit_command: ['echo', 'Shutting all the shit down!']
  is_running: -> Promise.resolve false
  cwd: "#{state.ROOTDIR}/rally-stack/stacker/etc"
  start_message: 'should never see this!'
