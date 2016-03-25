module.exports = (env) ->
  command = if env['pigeon-profile']?.length is 0
    ['lein', 'run']
  else
    ['lein', 'with-profile', env['pigeon-profile'], 'run']

  name: 'Pigeon'
  alias: 'p'
  command: command
  start_message: "on #{'127.0.0.1:3200'.magenta}"
  cwd: "#{env.ROOTDIR}/pigeon"
  shell_env:
    ZOOKEEPER_CONNECT: env.zookeeper_address
    STACK: env.schema
  args:
    'pigeon-profile':
      describe: 'pass a lein profile to pigeon'

  wait_for: /Ready to deliver your messages to Winterfell, sir!|(RuntimeException)/
  callback: (data, env) ->
    [match, exception] = data
    if exception
      util.error 'Warning: Pigeon failed to connect to Marshmallow'.yellow, data.input ? data
    env
