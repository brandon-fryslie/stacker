rally = require './rally'
{die} = require './util'
_ = require 'lodash'
fs = require 'fs'

task_config =
  marshmallow: (env) ->
    name: 'Marshmallow'
    alias: 'm'
    command: ['lein', 'start-infrastructure']
    start_message: 'Starting Marshmallow.'
    cwd: "#{rally.ROOTDIR}/marshmallow"
    wait_for:  /ZOOKEEPER INIT:\s*([\w:]+)|(Connection timed out)/
    callback: (data, env) ->
      [match, zookeeper_address, error] = data
      if error
        die 'Marshmallow connection timed out: ', data

      unless zookeeper_address
        die 'Error: could not find zookeeper address in: ', match

      console.log 'Zookeeper Address:', zookeeper_address.magenta

      new_env = _.assign {}, env, zookeeper_address: zookeeper_address
      new_env

  zuul: (env) ->
    name: 'Zuul'
    alias: 'z'
    command: ['lein', 'run']
    start_message: "Starting Zuul (#{'127.0.0.1:3000'.magenta}) with zk address #{env.zookeeper_address.magenta} and ZUUL_TENANT_OVERRIDE #{rally.get_schema_name.cyan}."
    cwd: "#{rally.ROOTDIR}/zuul"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      ZUUL_TENANT_OVERRIDE: rally.get_schema_name
    wait_for: /Server started!|(Connection timed out)|(Address already in use)|(All host pools marked down.)/
    callback: (data, env) ->
      [match, timeout_error, address_in_use_error, host_pool_down_error] = data
      if timeout_error || address_in_use_error || host_pool_down_error
        die 'Error: Zuul failed to connect to Marshmallow:', data.input ? data
      env

  'bag-boy': (env) ->
    name: 'Bag Boy'
    alias: 'bb'
    command: ['lein', 'run']
    start_message: "Starting Bagboy with zk address #{env.zookeeper_address.magenta}."
    cwd: "#{rally.ROOTDIR}/bag-boy"
    additional_env: ZOOKEEPER_CONNECT: env.zookeeper_address
    wait_for: /\|-BAG BOY-\||(Connection timed out)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        die 'Error: Bagboy failed to connect to Marshmallow', data.input ? data
      env

  birdseed: (env) ->
    name: 'Birdseed'
    alias: 'bs'
    command: ['lein', 'run']
    start_message: "Starting Birdseed with zk address #{env.zookeeper_address.magenta} and schema name #{rally.get_schema_name.cyan}."
    cwd: "#{rally.ROOTDIR}/birdseed"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      BIRDSEED_SCHEMAS: rally.get_schema_name
      DEV_MODE: false
    wait_for: /Hey little birdies, here comes your seed|(Connection timed out)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        die 'Error: Birdseed failed to connect to Marshmallow', data.input ? data
      env

  alm: (env) ->
    command = ['./gradlew', 'jettyRun']
    additional_env = {}

    if env.zookeeper_address
      additional_env['ZOOKEEPER_CONNECT'] = env.zookeeper_address

    if env.with_local_appsdk
      additional_env['APPSDK_PATH'] = "#{rally.ROOTDIR}/appsdk"

    if env.with_local_app_catalog
      additional_env['APP_CATALOG_PATH'] = "#{rally.ROOTDIR}/app-catalog"

    if env.clean_alm
      idx = command.indexOf('jettyRun')
      if idx > -1
        command.splice(idx, 0, 'clean')

    if env.db_migrations
      idx = command.indexOf('jettyRun')
      if idx > -1
        command.splice(idx, 0, 'dbM')

    if env.with_local_burro
      additional_env['BURRO_URL'] = env.burro_address

    msg = "Starting ALM (#{'127.0.0.1:7001'.magenta})"
    msg += if env.zookeeper_address then ' with zk address ' + env.zookeeper_address.magenta else ''
    msg += if env.with_local_appsdk then " with local #{'appsdk'.cyan}" else ''
    msg += if env.with_local_app_catalog then " with local #{'app catalog'.cyan}" else ''
    msg += if env.with_local_burro then " with local #{'burro'.cyan} at #{env.burro_address.magenta}" else ''
    msg += if env.with_local_churro then " with local #{'churro'.cyan}" else ''

    # check for symlinked churro + sombrero
    try
      stat = fs.lstatSync("#{process.env.WEBAPP_HOME}/node_modules/churro")
      msg += if stat.isSymbolicLink() then " with symlinked #{'churro'.cyan}" else ''
      try
        stat = fs.lstatSync("#{process.env.WEBAPP_HOME}/node_modules/churro/node_modules/sombrero")
        msg += if stat.isSymbolicLink() then " with symlinked #{'sombrero'.cyan}" else ''
      catch e
        console.log 'Could not find sombrero.  Try npm install'.yellow
    catch e
      console.log 'Could not find churro.  Try npm install'.yellow

    name: 'ALM'
    alias: 'a'
    command: command
    start_message: "#{msg}."
    cwd: process.env.WEBAPP_HOME
    additional_env: additional_env ? {}
    wait_for: /Started SelectChannelConnector@0.0.0.0:7001|(error)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        die 'Error: ALM failed to connect to Marshmallow', data.input ? data
      env

  pigeon: (env) ->
    name: 'Pigeon'
    alias: 'p'
    command: ['lein', 'run']
    start_message: "Starting Pigeon (#{'127.0.0.1:3200'.magenta}) with STACK=#{"#{rally.get_schema_name}".cyan}."
    cwd: "#{rally.ROOTDIR}/pigeon"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      STACK: rally.get_schema_name
    wait_for: /Ready to deliver your messages to Winterfell, sir!|(RuntimeException)/
    callback: (data, env) ->
      [match, exception] = data
      if exception
        die 'Warning: Pigeon failed to connect to Marshmallow'.yellow, data.input ? data
      env

  burro: (env) ->
    command = ['npm', 'start']
    command.push("#{rally.ROOTDIR}/churro") if env.with_local_churro
    name: 'Burro'
    alias: 'b'
    command: command
    start_message: "Starting Burro (#{'127.0.0.1:8855'.magenta})#{if env.with_local_churro then " with local #{'churro'.cyan}" else ''}."
    cwd: "#{rally.ROOTDIR}/burro"
    wait_for: /Server running at: http:\/\/([\w.:]+)/
    callback: (data, env) ->
      [match, burro_address] = data
      env

  test: (env) ->
    name: 'Test'
    command: ['tail', '-f', 'stacker/task_config.coffee']
    start_message: 'test read'
    wait_for: /The Words You Are Reading Right Now!/
    callback: (a,b,c) ->

  error: (env) ->
    name: 'Error'
    command: ['tail', '-f', 'non-existent-file.coffee']
    start_message: 'test error'
    wait_for: /Peace in the middle east/
    callback: (a,b,c) ->
      console.log 'error'
      console.log a,b,c

module.exports =
  task_config
