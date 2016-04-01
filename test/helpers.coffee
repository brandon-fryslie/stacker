require 'colors'
{pipe_with_prefix} = require '../lib/util'
mexpect = require '../lib/mexpect'

module.exports =
  Stacker: class Stacker
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

    exit: (done) ->
      @send_cmd 'exit'
      @wait_for(/Killed running tasks!/).then -> done()

      # This is to handle the case where stacker displays usage information and exits
      @wait_for(/☃/).then -> done()
