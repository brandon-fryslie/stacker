module.exports = (state) ->
  command = ['./gradlew', 'jettyRun']
  shell_env =
    MESSAGE_QUEUE_TYPE: 'KAFKA'
    START_MARSHMALLOW: 'true'

  if state.zookeeper_address
    shell_env['ZOOKEEPER_CONNECT'] = state.zookeeper_address

  if state.with_local_appsdk
    shell_env['APPSDK_PATH'] = "#{state.ROOTDIR}/appsdk"

  if state.with_local_app_catalog
    shell_env['APP_CATALOG_PATH'] = "#{state.ROOTDIR}/app-catalog"

  if state.with_local_churro
    shell_env['BURRO_URL'] = state.burro_address

  if state.with_local_churro
    shell_env['BURRO_URL'] = state.burro_address

  if state.with_local_zuul
    shell_env['ZUUL_HOSTNAME'] = 'http://localhost:3000'

  name: 'ALM'
  alias: 'a'
  command: command
  start_message: "on #{'127.0.0.1:7001'.magenta}"
  cwd: process.env.WEBAPP_HOME
  shell_env: shell_env
  args:
    'with-local-appsdk':
      alias: 'sdk'
      describe: 'Use local appsdk at ~/projects/appsdk'
    'with-local-app-catalog':
      describe: 'Use local app-catalog at ~/projects/app-catalog'
    'with-local-churro':
      alias: 'chur'
      describe: 'Use local churro at ~/projects/churro'
  wait_for: /Started SelectChannelConnector@0.0.0.0:7001|(error)/
  callback: (state, data) ->
    [match, timeout_error] = data
    if timeout_error
      util.error 'Error: ALM failed to connect to Marshmallow', data.input ? data
