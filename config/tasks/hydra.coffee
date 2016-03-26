module.exports = (state) ->
  name: 'Hydra'
  alias: 'h'
  command: ['lein', 'run']
  start_message: "on #{'127.0.0.1:4000'.magenta}"
  cwd: "#{state.ROOTDIR}/hydra"
  shell_env:
    ZOOKEEPER_CONNECT: state.zookeeper_address
  wait_for: /hydra listening on port 4000|(RuntimeException)/
  callback: (state, data) ->
    [match, exception] = data
    if exception
      util.error 'Warning: Hydra failed to connect to Marshmallow'.yellow, data.input ? data
    state
