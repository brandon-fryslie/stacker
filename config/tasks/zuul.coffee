module.exports = (env) ->
  name: 'Zuul'
  alias: 'z'
  command: ['lein', 'with-profile', 'oracle', 'run']
  start_message: "on #{'127.0.0.1:3000'.magenta}"
  cwd: "#{env.ROOTDIR}/zuul"
  shell_env:
    DATASTORE_OVERRIDE: 'db'
    ZOOKEEPER_CONNECT: env.zookeeper_address
    ZUUL_TENANT_OVERRIDE: env.schema
  wait_for: /Server started!|(Connection timed out)|(Address already in use)|(All host pools marked down.)/
  callback: (data, env) ->
    [match, timeout_error, address_in_use_error, host_pool_down_error] = data
    if timeout_error || address_in_use_error || host_pool_down_error
      util.error 'Error: Zuul failed to connect to Marshmallow:', data.input ? data
    env.with_local_zuul = true
    env
