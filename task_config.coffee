rally = require './rally'
util = require './util/util'
repl_lib = require './lib/repl_lib'
_ = require 'lodash'
fs = require 'fs'

{run_cmd} = require './lib/task_lib'

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
    additional_env =
      MESSAGE_QUEUE_TYPE: 'KAFKA'
      START_MARSHMALLOW: 'true'

    if env.zookeeper_address
      additional_env['ZOOKEEPER_CONNECT'] = env.zookeeper_address

    if env.with_local_appsdk
      additional_env['APPSDK_PATH'] = "#{rally.ROOTDIR}/appsdk"

    if env.with_local_app_catalog
      additional_env['APP_CATALOG_PATH'] = "#{rally.ROOTDIR}/app-catalog"

    if env.with_local_churro
      additional_env['BURRO_URL'] = env.burro_address

    name: 'ALM'
    alias: 'a'
    command: command
    start_message: "on #{'127.0.0.1:7001'.magenta}"
    cwd: process.env.WEBAPP_HOME
    additional_env: additional_env
    wait_for: /Started SelectChannelConnector@0.0.0.0:7001|(error)/
    callback: (data, env) ->
      [match, timeout_error] = data
      if timeout_error
        util.error 'Error: ALM failed to connect to Marshmallow', data.input ? data
      env

  'docker-oracle': (env) ->
    name: 'Docker Oracle'
    alias: 'do'
    command: ['lein', 'start-docker-oracle']
    cwd: "#{rally.ROOTDIR}/pigeon"
    additional_env:
      DOCKER_HOST: "tcp://bld-docker-16:4243"
      DEV_MODE: true

    exit_command: ['lein', 'stop-docker-oracle']
    # -> (Promise -> boolean)
    is_running: ->
      container_name = "dev-#{util.get_hostname().replace(/[\W]/g, '-')}-pigeon"

      util.repl_print "Looking for docker container #{container_name.cyan}..."

      mproc = run_cmd
        cmd: ["docker ps -a | grep #{container_name}"]
        cwd: @cwd
        env: @additional_env
        pipe_output: false

      mproc.on_close.then ([code, signal]) ->
        code is 0

    cleanup: ->
      container_name = "dev-#{util.get_hostname().replace(/[\W]/g, '-')}-pigeon"

      util.repl_print "Cleaning up docker container #{container_name}..."

      run_cmd
        cmd: ["docker ps -a | grep #{container_name} | awk '{print $1}' | xargs docker rm -f"]
        cwd: @cwd
        env: @additional_env
        pipe_output: false
      .on_close

    wait_for: /WRITING JDBC CONFIG|(Conflict)/
    callback: (data, env) ->
      [match, exception] = data
      if exception
        util.error 'Warning: Conflict trying to create new oracle docker container.  Delete the old one'.yellow, data.input ? data
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
    name: 'Burro'
    alias: 'b'
    command: ['npm', 'run', 'dev']
    start_message: "on #{'127.0.0.1:8855'.magenta} with local #{'churro'.cyan}."
    cwd: "#{rally.ROOTDIR}/burro"
    wait_for: /Server running at: http:\/\/([\w.:]+)/
    callback: (data, env) ->
      [match, burro_address] = data
      env

  'realtime-nginx': (env) ->
    name: 'realtime-nginx'
    alias: 'rn'
    command: ['realtime-nginx']
    start_message: "on #{'rally.dev:8999'.magenta}."
    cwd: "#{rally.ROOTDIR}/burro"
    wait_for: /Started/
    is_running: ->
      run_cmd
        cmd: ["ps -ax | grep -v grep |  grep realtime-nginx-conf"]
        cwd: @cwd
        pipe_output: false
      .on_close.then ([code, signal]) ->
        code is 0

    exit_command: ['nginx', '-s', 'stop']
    callback: (data, env) ->
      [match, pid, nginx_conf] = data
      env

  hydra: (env) ->
    name: 'Hydra'
    alias: 'h'
    command: ['lein', 'run']
    start_message: "on #{'127.0.0.1:4000'.magenta}"
    cwd: "#{rally.ROOTDIR}/hydra"
    additional_env:
      ZOOKEEPER_CONNECT: env.zookeeper_address
    wait_for: /hydra listening on port 4000|(RuntimeException)/
    callback: (data, env) ->
      [match, exception] = data
      if exception
        util.error 'Warning: Hydra failed to connect to Marshmallow'.yellow, data.input ? data
      env

  test: (env) ->
    name: 'Test'
    alias: 't'
    command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
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

  # this is going away
  'test-on-close': (env) ->
    name: 'TestOnClose'
    command: ['./display-after-1-second.sh', 'Hi There!']
    cwd: "#{rally.ROOTDIR}/rally-stack/stacker/etc"
    start_message: 'test close callback'
    wait_for: /The/
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command successfully run!']

  'test-daemon': (env) ->
    name: 'Test Daemon'
    alias: 'td'
    command: ['echo', 'Started all the test infrastructures!!']
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve false
    cleanup: ->
      repl_lib.print 'Cleaning things up!  For serious'.yellow
      run_cmd
        cmd: ['echo', 'Cleaning up after test daemon...']
      .on_close
    cwd: "#{rally.ROOTDIR}/rally-stack/stacker/etc"
    start_message: 'test daemon procs'
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command run!']

  'always-on-daemon': (env) ->
    name: 'Test Daemon'
    alias: 'aod'
    command: ['echo', 'Started all the test infrastructures!!']
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve true
    cleanup: ->
      repl_lib.print 'Cleaning things up!  For serious'.yellow
      run_cmd
        cmd: ['echo', 'Cleaning up after test daemon...']
      .on_close
    cwd: "#{rally.ROOTDIR}/rally-stack/stacker/etc"
    start_message: 'daemon is always running'
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command run!']

  'fail-daemon': (env) ->
    name: 'Fail Daemon'
    alias: 'fd'
    command: ["head #{module.filename}"]
    wait_for: /Neva gonna happen/
    exit_command: ['echo', 'Shutting all the shit down!']
    is_running: -> Promise.resolve false
    cwd: "#{rally.ROOTDIR}/rally-stack/stacker/etc"
    start_message: 'should never see this!'

  'test-clone': (env) ->
    name: 'Test Clone'
    alias: 'tc'
    command: ['echo', 'Started all the test infrastructures!!']
    exit_command: ['rm', '-rf', "#{rally.ROOTDIR}/ops-dashboard"]
    cwd: "#{rally.ROOTDIR}/ops-dashboard"
    start_message: 'test daemon procs'
    onClose: (code, signal) ->
      run_cmd cmd: ['echo', 'Exit command run!']

module.exports =
  task_config
