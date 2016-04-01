require 'colors'
_ = require 'lodash'
fs = require 'fs'
path = require 'path'
nodeREPL = require 'repl'
util = require './util'

# This code is copied/modified from the CoffeeScript source code
# from coffeescript/src/repl.coffee
#
# Copyright (c) 2009-2015 Jeremy Ashkenas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# global reference to the repl
REPL = {}

# repl commands
# a map of command objects:
# {
#   my_command:
#     name: 'my_command'
#     help: 'usage: my_command [options]'
#     alias: 'my'
#     fn: (opts) -> do_stuff()
# }
COMMANDS = {}

# aliases for repl commands
# a map like this:
# 'alias': 'command_name'
ALIAS = {}

resolve_command_name = (command) -> ALIAS[command] ? command

setup_keybindings = (repl) ->
  repl.inputStream.on 'keypress', (char, key) ->
    REPL.displayPrompt?(true)

# Store and load command history from a file
addHistory = (repl, filename, maxSize) ->
  lastLine = null
  try
    # Get file info and at most maxSize of command history
    stat = fs.statSync filename
    size = Math.min maxSize, stat.size
    # Read last `size` bytes from the file
    readFd = fs.openSync filename, 'r'
    buffer = new Buffer(size)
    fs.readSync readFd, buffer, 0, size, stat.size - size
    # Set the history on the interpreter
    repl.rli.history = buffer.toString().split('\n').reverse()
    # If the history file was truncated we should pop off a potential partial line
    repl.rli.history.pop() if stat.size > maxSize
    # Shift off the final blank newline
    repl.rli.history.shift() if repl.rli.history[0] is ''
    repl.rli.historyIndex = -1
    lastLine = repl.rli.history[0]
  catch e

  fd = fs.openSync filename, 'a'

  repl.rli.addListener 'line', (code) ->
    if code and code.length and code isnt 'history' and lastLine isnt code
      # Save the latest command in the file
      fs.write fd, "#{code}\n"
      lastLine = code

  repl.rli.on 'exit', -> fs.close fd

getCommandId = (repl, commandName) ->
  # Node 0.11 changed API, a command such as '.help' is now stored as 'help'
  commandsHaveLeadingDot = repl.commands['.help']?
  if commandsHaveLeadingDot then ".#{commandName}" else commandName

complete_command = (token) ->
  _(COMMANDS).pluck('name').filter((name) -> name.match(///^#{token}///)).value()

# ([string]) -> [string]
complete_arguments = (args) ->
  cmd = args.shift()
  choices = COMMANDS[cmd]?.tab_complete(args)
  _.filter choices, (name) -> name.match(///#{args[args.length-1]}///)

# not hooked up. in progress...not sure if will be finished
patch_repl_tab_complete = (repl) ->
  idx = 0
  repl.complete = (line, callback) ->
    tokens = line.split(/\s/)

    completions = if tokens.length > 1 or line.match /(\w)+\s+$/
      complete_arguments tokens
    else
      complete_command tokens[0]

    # if command matches exactly, move to next index?

    if completions.length > 1
      util.print completions.join('  ')
      idx = if idx >= completions.length then 0 else idx
      completions = [completions[idx++]]

    if completions.length > 0
      callback(null, [completions, line])

exports =
  add_command: (command) ->
    COMMANDS[command.name] = command
    if command.alias?
      ALIAS[command.alias] = command.name

  add_alias: (alias) -> _.merge(ALIAS, alias)

  get_commands: -> COMMANDS

  clear_line: -> REPL.rli.clearLine(process.stdin, 0)

  get_repl: -> REPL

  start: ->
    opts =
      prompt: '> '
      historyFile: path.join(process.env.HOME, '.stacker_history') if process.env.HOME
      historyMaxInputSize: 10240
      ignoreUndefined: true
      eval: (input, context, filename, cb) ->
        input = input.replace /\uFF00/g, '\n' # XXX: multiline hack.
        input = input.replace /^\(([\s\S]*)\n\)$/m, '$1' # Unwrap parens + \n
        input = input.split(' ') # split into [command arg arg arg...]

        command_name = resolve_command_name util.trim(input[0])
        args = _.map input[1...], util.trim

        command = COMMANDS[command_name]
        if command
          command.fn.apply command, args
        else
          util.print 'not a command:', command_name

          cb()

    REPL = nodeREPL.start opts

    # patch_repl_tab_complete REPL

    setup_keybindings REPL

    if opts.historyFile
      addHistory REPL, opts.historyFile, opts.historyMaxInputSize

    REPL

module.exports[k] = v for k, v of exports
