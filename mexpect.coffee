child_process = require('child_process')
stream = require 'stream'
_ = require 'lodash'

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
      @push line + '\n'

  , ->
    if @_lastLineData?
      @push @_lastLineData
      @_lastLineData = null


create_prefix_transform_stream = (prefix) ->
  create_transform_stream (line) ->
    @push "#{prefix} #{line}\n"

create_callback_transform_stream = (expectation, cb) ->
  create_transform_stream (line) ->
    # console.log "testing #{line} for #{expectation}"
    if expectation.test? and expectation.test(line) or line.toString().indexOf?(expectation) > -1
      data = expectation.exec?(line) ? [data]
      cb data

clone_apply = (obj1, obj2) ->
  newObj = {}
  newObj[k] = v for k, v of obj1
  newObj[k] = v for k, v of obj2
  newObj

get_env = (new_env) -> clone_apply process.env, new_env

class Mexpect

  wait_for: (expectation, cb) =>
    nl_stream = create_newline_transform_stream()
    cb_stream = create_callback_transform_stream expectation, cb
    @proc.stdout.pipe(nl_stream).pipe(cb_stream)
    @

  wait_for_once: (expectation, cb) =>
    nl_stream = create_newline_transform_stream()
    cb_stream = create_callback_transform_stream expectation, _.once cb
    @proc.stdout.pipe(nl_stream).pipe(cb_stream)
    @

  wait_for_err: (expectation, cb) =>
    nl_stream = create_newline_transform_stream()
    cb_stream = create_callback_transform_stream expectation, cb
    @proc.stderr.pipe(nl_stream).pipe(cb_stream)
    @

  spawn: (cmd, argv, opt={}) =>
    opt.cwd ?= process.cwd()
    opt.env ?= get_env()
    @proc = child_process.spawn(cmd, argv, opt)

    @proc.on 'error', ->
      console.log 'Got a proc error', arguments

    if opt.verbose
      line_stream = create_newline_transform_stream()
      prefix_stream = create_prefix_transform_stream '!!!'
      @proc.stdout.pipe(prefix_stream).pipe(line_stream).pipe process.stdout
      @proc.stderr.pipe(prefix_stream).pipe(line_stream).pipe process.stderr

    @

module.exports = new Mexpect