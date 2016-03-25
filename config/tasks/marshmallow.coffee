module.exports = (env, {_, print}) ->
  name: 'Marshmallow'
  alias: 'm'
  command: ['lein', 'start-infrastructure']
  cwd: "#{env.ROOTDIR}/marshmallow"
  wait_for:  /ZOOKEEPER INIT:\s*([\w:]+)|(Connection timed out)/
  callback: (data, env) ->
    [match, zookeeper_address, error] = data
    if error
      util.error 'Marshmallow connection timed out: ', data
      return env

    unless zookeeper_address
      util.error 'Error: could not find zookeeper address in: ', match
      return env

    print 'Zookeeper Address:', zookeeper_address.magenta

    new_env = _.assign {}, env, zookeeper_address: zookeeper_address
    new_env
