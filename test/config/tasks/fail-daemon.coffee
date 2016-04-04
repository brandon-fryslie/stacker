module.exports = (state) ->
  name: 'Fail Daemon'
  alias: 'fd'
  command: ['echo some stuff']
  wait_for: /Neva gonna happen/
  exit_command: ['echo', 'Shutting all the shit down!']
  is_running: -> Promise.resolve false
  start_message: 'should never see this!'
