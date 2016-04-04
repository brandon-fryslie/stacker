require 'colors'
{pipe_with_prefix} = require '../lib/util'
mexpect = require '../lib/mexpect'

Stacker = class Stacker
  constructor: (cmd = '', env = {}) ->
    stacker_bin = "#{__dirname}/../bin/stacker"
    env.STACKER_CONFIG_DIR = "#{__dirname}/config"
    @mproc = mexpect.spawn
      cmd: "#{stacker_bin} #{cmd}"
      env: env
    # @engageOutput()

  wait_for: (expectation) ->
    @mproc.on_data expectation

  send_cmd: (cmd) ->
    @mproc.proc.stdin.write "#{cmd}\n"

  engageOutput: ->
    pipe_with_prefix '---- stacker output'.magenta, @mproc.proc.stdout, process.stdout
    pipe_with_prefix '---- stacker output'.magenta, @mproc.proc.stderr, process.stderr

  exit: ->
    @send_cmd 'exit'
    # The snowman is there to handle the case where stacker displays usage information and exits
    @wait_for(/Killed running tasks!|☃/)

with_stacker = (cmd, fn) ->
  stacker = new Stacker cmd
  fn(stacker).then ->
    stacker.exit()

module.exports = {
  with_stacker
}
