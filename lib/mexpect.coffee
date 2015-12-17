require('es6-promise').polyfill()

child_process = require 'child_process'
stream = require 'stream'
_ = require 'lodash'

# this should be a utility somewhere...

create_transform_stream = (fn, flush_fn) ->
  liner = new stream.Transform()
  liner._transform = (chunk, encoding, done) ->
    fn.call @, chunk, encoding
    done()

  if flush_fn?
    liner._flush = (done) ->
      flush_fn.call @
      done()

  liner

create_newline_transform_stream = ->
  create_transform_stream (chunk) ->
    data = chunk.toString()
    if @_lastLineData?
      data = @_lastLineData + data

    lines = data.split('\n')
    @_lastLineData = lines.pop()

    for line in lines
      @push "#{line}\n"

  , ->
    if @_lastLineData?
      @push @_lastLineData
      @_lastLineData = null


create_prefix_transform_stream = (prefix) ->
  create_transform_stream (line) ->
    @push "#{prefix} #{line}\n"

create_callback_transform_stream = (expectation, cb) ->
  create_transform_stream (line) ->
    if expectation.test? and expectation.test(line) or line.toString().indexOf?(expectation) > -1
      data = expectation.exec?(line) ? [expectation]
      cb data

clone_apply = (obj1, obj2) ->
  newObj = {}
  newObj[k] = v for k, v of obj1
  newObj[k] = v for k, v of obj2
  newObj

class Mexpect

  wait_for: (expectation, cb) =>
    nl_stream = create_newline_transform_stream()
    cb_stream = create_callback_transform_stream expectation, cb
    @proc.stdout.pipe(nl_stream).pipe(cb_stream)
    @

  wait_for_once: (expectation, cb) =>
    @wait_for expectation, _.once cb

  wait_for_err: (expectation, cb) =>
    nl_stream = create_newline_transform_stream()
    cb_stream = create_callback_transform_stream expectation, cb
    @proc.stderr.pipe(nl_stream).pipe(cb_stream)
    @

  on_data: (expectation) ->
    new Promise (resolve, reject) =>
      @wait_for_once expectation, (matches) ->
        resolve matches

  on_err: (expectation) ->
    new Promise (resolve, reject) =>
      @wait_for_err expectation, (matches) ->
        resolve matches

  _spawn_bash: (cmd, cwd, env, opt) ->
    @proc = child_process.spawn 'bash', [],
      _.assign
        cwd: cwd
        env: env
      ,
        opt

    @proc.stdin.write "#{cmd.join(' ')}\n"
    @proc

  _spawn_direct: (cmd, cwd, env, opt) ->
    [cmd, argv...] = cmd
    @proc = child_process.spawn cmd, argv,
      _.assign
        cwd: cwd
        env: env
      ,
        opt

  # cmd: command to run
  # cwd: working dir for command (default: current process cwd)
  # env: shell env (default: current process env)
  # direct: run command directly (not using bash)
  spawn: (opt) =>
    {cmd, cwd, env, direct} = opt

    cmd = if _.isArray(cmd) then cmd else [cmd]
    cwd ?= process.cwd()
    env ?= process.env
    direct ?= false

    @proc = if direct
      @_spawn_direct cmd, cwd, env, opt
    else
      @_spawn_bash cmd, cwd, env, opt

    @on_close =
      new Promise (resolve, reject) =>
        @proc.on 'close', (code, signal) ->
          resolve [code, signal]

    @

module.exports =
  spawn: ->
    mexpect = new Mexpect
    mexpect.spawn.apply mexpect, arguments
    mexpect
