module.exports = (state) ->
  name: 'Zuul'
  alias: 'z'
  command: ['lein', 'with-profile', 'oracle', 'run']
  start_message: "on #{'127.0.0.1:3000'.magenta}"
  cwd: "#{state.ROOTDIR}/zuul"
  shell_env:
    DATASTORE_OVERRIDE: 'db'
    ZOOKEEPER_CONNECT: state.zookeeper_address
    ZUUL_TENANT_OVERRIDE: state.schema
  wait_for: /Server started!|(Connection timed out)|(Address already in use)|(All host pools marked down.)/
  callback: (state, data) ->
    [match, timeout_error, address_in_use_error, host_pool_down_error] = data
    if timeout_error or address_in_use_error or host_pool_down_error
      util.error 'Error: Zuul failed to connect to Marshmallow:', data.input ? data
    state.with_local_zuul = true
    state
