module.exports = (env) ->
  command = ['./gradlew', 'jettyRun']
  shell_env =
    MESSAGE_QUEUE_TYPE: 'KAFKA'
    START_MARSHMALLOW: 'true'

  if env.zookeeper_address
    shell_env['ZOOKEEPER_CONNECT'] = env.zookeeper_address

  if env.with_local_appsdk
    shell_env['APPSDK_PATH'] = "#{env.ROOTDIR}/appsdk"

  if env.with_local_app_catalog
    shell_env['APP_CATALOG_PATH'] = "#{env.ROOTDIR}/app-catalog"

  if env.with_local_churro
    shell_env['BURRO_URL'] = env.burro_address

  if env.with_local_churro
    shell_env['BURRO_URL'] = env.burro_address

  if env.with_local_zuul
    shell_env['ZUUL_HOSTNAME'] = 'http://localhost:3000'

  name: 'ALM'
  alias: 'a'
  command: command
  start_message: "on #{'127.0.0.1:7001'.magenta}"
  cwd: process.env.WEBAPP_HOME
  shell_env: shell_env
  wait_for: /Started SelectChannelConnector@0.0.0.0:7001|(error)/
  callback: (data, env) ->
    [match, timeout_error] = data
    if timeout_error
      util.error 'Error: ALM failed to connect to Marshmallow', data.input ? data
    env
