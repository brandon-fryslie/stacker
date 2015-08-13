rally = require './rally'
util = require './util'
repl_lib = require './repl'
_ = require 'lodash'
fs = require 'fs'

{run_cmd} = require './stacker'

task_config =
  marshmallow: (env) ->
    name: 'Marshmallow'
    alias: 'm'
    command: ['lein', 'start-infrastructure']
    cwd: "#{rally.ROOTDIR}/marshmallow"
    wait_for:  /ZOOKEEPER INIT:\s*([\w:]+)|(Connection timed out)/
    callback: (data, env) ->
      [match, zookeeper_address, error] = data
      if error
        util.error 'Marshmallow connection timed out: ', data
        return env

      unless zookeeper_address
        util.error 'Error: could not find zookeeper address in: ', match
        return env

      repl_lib.print 'Zookeeper Address:', zookeeper_address.magenta

      new_env = _.assign {}, env, zookeeper_address: zookeeper_address
      new_env

  zuul: (env) ->
    name: 'Zuul'
    alias: 'z'
    command: ['lein', 'run']
    start_message: "on #{'127.0.0.1:3000'.magenta}"
    cwd: "#{rally.ROOTDIR}/zuul"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      ZUUL_TENANT_OVERRIDE: env.schema
    wait_for: /Server started!|(Connection timed out)|(Address already in use)|(All host pools marked down.)/
    callback: (data, env) ->
      [match, timeout_error, address_in_use_error, host_pool_down_error] = data
      if timeout_error || address_in_use_error || host_pool_down_error
        util.error 'Error: Zuul failed to connect to Marshmallow:', data.input ? data
      env

  'bag-boy': (env) ->
    command = if env['bag-boy-profile'].length is 0
      ['lein', 'run']
    else
      ['lein', 'with-profile', env['bag-boy-profile'], 'run']

    name: 'Bag Boy'
    alias: 'bb'
    command: command
    cwd: "#{rally.ROOTDIR}/bag-boy"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
    wait_for: /\|-BAG BOY-\||(Connection timed out)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        util.error 'Error: Bagboy failed to connect to Marshmallow', data.input ? data
      env

  birdseed: (env) ->
    command = if env['birdseed-profile'].length is 0
      ['lein', 'run']
    else
      ['lein', 'with-profile', env['birdseed-profile'], 'run']

    name: 'Birdseed'
    alias: 'bs'
    command: command
    cwd: "#{rally.ROOTDIR}/birdseed"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      BIRDSEED_SCHEMAS: env.schema
    wait_for: /Hey little birdies, here comes your seed|(Connection timed out)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        util.error 'Error: Birdseed failed to connect to Marshmallow', data.input ? data
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

    if env.with_local_burro
      additional_env['BURRO_URL'] = env.burro_address

    msg = "on #{'127.0.0.1:7001'.magenta}"

    # check for symlinked churro + sombrero
    try
      stat = fs.lstatSync("#{process.env.WEBAPP_HOME}/node_modules/churro")
      msg += if stat.isSymbolicLink() then " with symlinked #{'churro'.cyan}" else ''
      try
        stat = fs.lstatSync("#{process.env.WEBAPP_HOME}/node_modules/churro/node_modules/sombrero")
        msg += if stat.isSymbolicLink() then " with symlinked #{'sombrero'.cyan}" else ''
      catch e
    catch e

    name: 'ALM'
    alias: 'a'
    command: command
    start_message: msg
    cwd: process.env.WEBAPP_HOME
    additional_env: additional_env ? {}
    wait_for: /Started SelectChannelConnector@0.0.0.0:7001|(error)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        util.error 'Error: ALM failed to connect to Marshmallow', data.input ? data
      env

  pigeon: (env) ->
    command = if env['pigeon-profile'].length is 0
      ['lein', 'run']
    else
      ['lein', 'with-profile', env['pigeon-profile'], 'run']

    name: 'Pigeon'
    alias: 'p'
    command: command
    start_message: "on #{'127.0.0.1:3200'.magenta}"
    cwd: "#{rally.ROOTDIR}/pigeon"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
      STACK: env.schema
    wait_for: /Ready to deliver your messages to Winterfell, sir!|(RuntimeException)/
    callback: (data, env) ->
      [match, exception] = data
      if exception
        util.error 'Warning: Pigeon failed to connect to Marshmallow'.yellow, data.input ? data
      env

  "mock-pigeon": (env) ->
    name: 'MockPigeon'
    alias: 'mp'
    command: ['npm', 'start']
    start_message: "on #{'127.0.0.1:3200'.magenta}"
    cwd: "#{rally.ROOTDIR}/mock-pigeon"
    wait_for: /Electron ./
    callback: (data, env) ->
      [match, exception] = data
      if exception
        util.error 'Warning: MockPigeon failed:'.yellow, data.input ? data
      env

  burro: (env) ->
    command = ['npm', 'run', 'dev']
    command.push("#{rally.ROOTDIR}/churro") if env.with_local_churro
    name: 'Burro'
    alias: 'b'
    command: command
    start_message: "on #{'127.0.0.1:8855'.magenta}#{if env.with_local_churro then " with local #{'churro'.cyan}" else ''}."
    cwd: "#{rally.ROOTDIR}/burro"
    wait_for: /Server running at: http:\/\/([\w.:]+)/
    callback: (data, env) ->
      [match, burro_address] = data
      env

  "churro-webpack": (env) ->
    name: 'Churro WebpackDevServer'
    alias: 'cwpds'
    command: ['grunt', 'webpack-dev-server']
    start_message: "on #{'127.0.0.1:1337'.magenta}"
    cwd: "#{rally.ROOTDIR}/churro"
    check: ->
      isNodeTen = parseInt(process.versions.node.split?('.')?[1]) is 10

      unless isNodeTen
        util.log_error 'Warning: this task is only compatible with node v0.10.'

      isNodeTen
    wait_for: /webpack-dev-server on port (\d+)/
    callback: (data, env) ->
      [match, webpack_port] = data
      env.webpack_address = "localhost:#{webpack_port}"
      env

  test: (env) ->
    name: 'Test'
    alias: 't'
    command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/boot-realtime"]
    start_message: 'Testing a basic task...'
    wait_for: /stacker/

  error: (env) ->
    name: 'Error'
    command: ['tail', '-f', 'non-existent-file.coffee']
    start_message: 'test error'
    wait_for: /Peace in the middle east/
    callback: (a,b,c) ->
      repl_lib.print 'error'
      repl_lib.print a,b,c

  'cwd-missing': (env) ->
    name: 'Error'
    command: ['echo', 'pillow']
    cwd: '/bla/bla/bla'
    start_message: 'test missing cwd'
    callback: (a,b,c) ->
      repl_lib.print 'error'
      repl_lib.print a,b,c

  'test-on-close': (env) ->
    name: 'TestOnClose'
    command: ['./display-after-1-second.sh', 'Hi There!']
    cwd: "#{rally.ROOTDIR}/rally-stack/stacker/etc"
    start_message: 'test close callback'
    wait_for: /The/
    onClose: (code, signal) ->
      run_cmd ['echo', 'Exit command successfully run!']

module.exports =
  task_config
