module.exports = (state) ->
  command = if state['pigeon-profile']?.length is 0
    ['lein', 'run']
  else
    ['lein', 'with-profile', state['pigeon-profile'], 'run']

  name: 'Pigeon'
  alias: 'p'
  command: command
  start_message: "on #{'127.0.0.1:3200'.magenta}"
  cwd: "#{state.ROOTDIR}/pigeon"
  shell_env:
    ZOOKEEPER_CONNECT: state.zookeeper_address
    STACK: state.schema
  args:
    'pigeon-profile':
      describe: 'pass a lein profile to pigeon'

  wait_for: /Ready to deliver your messages to Winterfell, sir!|(RuntimeException)/
  callback: (state, data) ->
    [match, exception] = data
    if exception
      util.error 'Warning: Pigeon failed to connect to Marshmallow'.yellow, data.input ? data
    state
