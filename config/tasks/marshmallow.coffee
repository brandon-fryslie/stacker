module.exports = (state, util) ->
  name: 'Marshmallow'
  alias: 'm'
  command: ['lein', 'start-infrastructure']
  cwd: "#{state.ROOTDIR}/marshmallow"
  wait_for:  /ZOOKEEPER INIT:\s*([\w:]+)|(Connection timed out)/
  callback: (state, data) ->
    [match, zookeeper_address, error] = data
    if error
      util.error 'Marshmallow connection timed out: ', data
      return state

    unless zookeeper_address
      util.error 'Error: could not find zookeeper address in: ', match
      return state

    util.print 'Zookeeper Address:', zookeeper_address.magenta

    new_state = util._.assign {}, state, zookeeper_address: zookeeper_address
    new_state
