module.exports = (state) ->
  name: 'MockPigeon'
  alias: 'mp'
  command: ['npm', 'start']
  start_message: "on #{'127.0.0.1:3200'.magenta}"
  cwd: "#{state.ROOTDIR}/mock-pigeon"
  wait_for: /Electron ./
  callback: (state, data) ->
    [match, exception] = data
    if exception
      util.error 'Warning: MockPigeon failed:'.yellow, data.input ? data
    state
