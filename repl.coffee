fs = require 'fs'
path = require 'path'
vm = require 'vm'
nodeREPL = require 'repl'
_ = require 'lodash'
util = require './util'
require 'colors'

# global reference to the repl
REPL = {}

# repl commands
# an array of command objects:
# [
#   name: 'my_command'
#   help: 'usage: my_command [options]'
#   alias: 'my'
#   fn: (opts) -> do_stuff()
# ]
COMMANDS = []

# aliases for repl commands
# a map like this:
# 'alias': 'command_name'
ALIAS = {}

resolve_command_name = (command) -> ALIAS[command] ? command

replDefaults =
  prompt: '> ',
  historyFile: path.join(process.env.HOME, '.stacker_history') if process.env.HOME
  historyMaxInputSize: 10240
  ignoreUndefined: true
  eval: (input, context, filename, cb) ->
    input = input.replace /\uFF00/g, '\n' # XXX: multiline hack.
    input = input.replace /^\(([\s\S]*)\n\)$/m, '$1' # Unwrap parens + \n
    input = input.split(' ') # split into [command arg arg arg...]

    command_name = resolve_command_name util.trim(input[0])
    args = _.map input[1...], util.trim

    command = _.find COMMANDS, name: command_name
    if command
      command.fn.apply this, args
    else
      console.log 'not a command:', command_name

    cb()

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
    if code and code.length and code isnt '.history' and lastLine isnt code
      # Save the latest command in the file
      fs.write fd, "#{code}\n"
      lastLine = code

  repl.rli.on 'exit', -> fs.close fd

  # Add a command to show the history stack
  repl.commands[getCommandId(repl, 'history')] =
    help: 'Show command history'
    action: ->
      repl.outputStream.write "#{repl.rli.history[..].reverse().join '\n'}\n"
      repl.displayPrompt()

getCommandId = (repl, commandName) ->
  # Node 0.11 changed API, a command such as '.help' is now stored as 'help'
  commandsHaveLeadingDot = repl.commands['.help']?
  if commandsHaveLeadingDot then ".#{commandName}" else commandName

patch_repl_tab_complete = (repl) ->
  idx = 0
  repl.complete = (line, callback) ->
    line = line.replace(/^\s|\s$/g, '')

    completions = _(COMMANDS).pluck('name').filter((name) ->
      name.match ///^#{line}///
    ).value()

    if completions.length > 1
      console.log completions.join('  ')
      idx = if idx >= completions.length then 0 else idx
      completions = [completions[idx++]]

    if completions.length > 0
      callback(null, [completions, line])

module.exports =
  add_command: (command) ->
    COMMANDS.push command
    if command.alias?
      ALIAS[command.alias] = command.name

  add_alias: (alias) -> _.merge(ALIAS, alias)

  get_commands: -> COMMANDS

  start: (opts = {}) ->
    [major, minor, build] = process.versions.node.split('.').map (n) -> parseInt(n)

    if major is 0 and minor < 8
      console.warn "Node 0.8.0+ required for CoffeeScript REPL"
      process.exit 1

    opts = _.merge replDefaults, opts
    repl = nodeREPL.start opts
    REPL = repl

    patch_repl_tab_complete repl

    setup_keybindings repl
    addHistory repl, opts.historyFile, opts.historyMaxInputSize if opts.historyFile
    # Adapt help inherited from the node REPL
    repl.commands[getCommandId(repl, 'load')].help = 'Load code from a file into this REPL session'

    repl