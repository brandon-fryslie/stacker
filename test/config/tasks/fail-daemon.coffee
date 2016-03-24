module.exports = (env) ->
  name: 'Fail Daemon'
  alias: 'fd'
  command: ["echo some stuff"]
  wait_for: /Neva gonna happen/
  exit_command: ['echo', 'Shutting all the shit down!']
  is_running: -> Promise.resolve false
  cwd: "#{env.ROOTDIR}/rally-stack/stacker/etc"
  start_message: 'should never see this!'
