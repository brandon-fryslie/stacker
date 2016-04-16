_ = require 'lodash'
require 'colors'
temp = require 'temp'
fs = require 'fs'
util = require '../lib/util'
mexpect = require '../lib/mexpect'

Stacker = class Stacker
  constructor: (cmd = '', env = {}) ->
    stacker_bin = "#{__dirname}/../bin/stacker"
    @mproc = mexpect.spawn
      cmd: "#{stacker_bin} #{cmd}"
      env: env
    # @engageOutput()

  wait_for: (expectation) ->
    @mproc.on_data expectation

  send_cmd: (cmd) ->
    @mproc.proc.stdin.write "#{cmd}\n"

  engageOutput: ->
    util.pipe_with_prefix '---- stacker output'.magenta, @mproc.proc.stdout, process.stdout
    util.pipe_with_prefix '---- stacker output'.magenta, @mproc.proc.stderr, process.stderr

  exit: ->
    @send_cmd 'exit'
    # The snowman is there to handle the case where stacker displays usage information and exits
    @wait_for(/Killed running tasks!|☃/)

with_stacker = (opt, fn) ->
  dirPath = null
  if opt.stacker_config? or !_.isEmpty opt.task_config
    dirPath = temp.mkdirSync()
    opt.env ?= {}
    opt.env.STACKER_CONFIG_DIR = dirPath

  if opt.stacker_config?
    fs.writeFileSync "#{dirPath}/config.coffee", opt.stacker_config

  if !_.isEmpty opt.task_config
    fs.mkdirSync("#{dirPath}/tasks")
    for name, config of opt.task_config
      fs.writeFileSync "#{dirPath}/tasks/#{name}.coffee", config

  stacker = new Stacker opt.cmd, opt.env
  fn(stacker).then ->
    stacker.exit()

module.exports = {
  with_stacker
}
