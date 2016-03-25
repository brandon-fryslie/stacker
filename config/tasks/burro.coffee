module.exports = (state) ->
  name: 'Burro'
  alias: 'b'
  command: ['npm', 'run', 'dev']
  start_message: "on #{'127.0.0.1:8855'.magenta} with local #{'churro'.cyan}."
  cwd: "#{state.ROOTDIR}/burro"
  wait_for: /Server running at: http:\/\/([\w.:]+)/
  callback: (state, data) ->
    [match, burro_address] = data
    state
