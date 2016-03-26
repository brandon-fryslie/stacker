_ = require 'lodash'
require 'colors'
stream = require 'stream'
os = require 'os'
path = require 'path'
rl = require 'readline'

DEBUG = false

move_cursor_to_beginning_of_line = ->
  process.stdout.write '\x1b[G'

# print something with a prefix
prefix_print = (prefix, str...) ->
  str.splice 0, 0, prefix

  str = for s in str
    "#{s}".split('\n').join("\n#{prefix} ")

  move_cursor_to_beginning_of_line()
  console.log.apply console, str

# exposed function for printing messages from stacker itself
print = (str...) ->
  str.unshift '\rstacker:'.bgWhite.black
  prefix_print.apply null, str

# throw exception and print error
error = (msg...) ->
  log_error.apply null, msg
  throw new Error msg

# only print error
log_error = (msg...) ->
  msg = color_array msg, 'red'
  print.apply null, msg

# only print error
log_error = (msg...) ->
  msg = color_array msg, 'red'
  print.apply null, msg

# debug logging
get_debug = ->
  DEBUG

set_debug = (areas) ->
  DEBUG = areas

_log = (area, args...) ->
  area = path.basename(area).replace(/\.\w+$/, '')
  if DEBUG is true or _.includes DEBUG, area
    process.stdout.write "DEBUG #{area}:".bgRed.black + ' '
    console.log.apply console, args

log_proc_error = (err) ->
  msg = switch err.code
    when 'ENOENT' then 'File not found'
    when 'EPIPE' then 'Writing to closed pipe'
    else err.code

  log_error "Error: #{task_name} #{err.code} #{msg}"

# color an array of strings
color_array = (array, color) ->
  for s in array
    if typeof s is 'string' and s[color] then s[color] else s

pretty_command_str = (command, shell_env = {}) ->
  ['$>'.gray.bold, ("#{k}".blue.bold + '='.gray + "#{v}".magenta for k, v of shell_env).join(' '), "#{command.join(' ')}".green].join(' ')

beautify_obj = (obj, level = 0) ->
  res = for k, v of obj
    v = if _.isArray(v)
      if _.isEmpty(v) then '[]' else v.join(', ')
    else if _.isObject(v)
      if _.isEmpty(v) then '{}' else '\n' + beautify_obj(v, level + 1)
    else
      v
    _.repeat(' ', level * 2) + "#{k}".blue.bold + '='.gray + "#{v}".magenta
  res.join '\n'

##########################################
#  Pipe streams with a colored prefix
##########################################
clrs = [
  ((s) -> s.bgMagenta.black)
  ((s) -> s.bgCyan.black)
  ((s) -> s.bgGreen.black)
  ((s) -> s.bgBlue)
  ((s) -> s.bgYellow.black)
  ((s) -> s.bgRed)
]
clr_idx = 0
get_color_fn = -> clrs[clr_idx++ % clrs.length]

create_prefix_stream_transformer = (prefix) ->
  liner = new stream.Transform()
  liner._transform = (chunk, encoding, done) ->
    data = chunk.toString()
    if @_lastLineData?
      data = @_lastLineData + data

    lines = data.split('\n')
    @_lastLineData = lines.pop()

    for line in lines
      @push "\r#{prefix} #{line}\n"

    done()

  liner._flush = (done) ->
    if @_lastLineData?
      @push @_lastLineData
      @_lastLineData = null
    done()

  liner

pipe_with_prefix = (prefix, from, to) ->
  from.pipe(create_prefix_stream_transformer(prefix)).pipe(to)

prefix_pipe_output = (prefix, task_proc) ->
  prefix = get_color_fn()("#{prefix}:")
  pipe_with_prefix prefix, task_proc.stdout, process.stdout
  pipe_with_prefix prefix, task_proc.stderr, process.stderr

##########################################
#  / stream coloring
##########################################

# wait for one key
# then resolve a promise
wait_for_keypress = ->
  new Promise (resolve, reject) ->
    process.stdin.once 'data', (char) ->
      process.stdout.clearLine()
      resolve char

# extract first capture group from regex
# (regex, string) -> string
regex_extract = (regex, str) ->
  data = regex.exec str
  unless data
    error 'Could not find match in', regex, str
  [match, group1] = data
  unless group1
    error 'Could not find match for group in', regex, str
  group1

clone_apply = (obj1, obj2) ->
  newObj = {}
  newObj[k] = v for k, v of obj1
  newObj[k] = v for k, v of obj2
  newObj

trim = (s) -> s.replace /(^\s*)|(\s*$)/g, ''

object_map = (obj, fn) ->
  _.reduce obj, (res, v, k) ->
    _.merge res, fn(k, v)
  , {}

print_process_status = (name, exit_code, signal) ->
  status = switch
    when exit_code is 0 then 'exited successfully'.green
    when exit_code? then "exited with code #{exit_code}"
    when signal? then "exited with signal #{signal}"
    else 'no exit code and no signal - should investigate'
  print name.cyan, status

# Int, Str -> ?
kill_tree = (pid, signal = 'SIGKILL') ->
  psTree = require('ps-tree')
  psTree pid, (err, children) ->
    [pid].concat(_.map(children, 'PID')).forEach (pid) ->
      try
        process.kill(pid, signal)
      catch e
        if e.code isnt 'ESRCH'
          throw e

############ cloning shit ############
try_to_clone = (task_name, repo_name) ->
  new Promise (resolve, reject) ->
    util.print "You don't have #{repo_name}.  Try cloning? [yn]".yellow
    wait_for_keypress().then (char) ->
      repl_lib.clear_line()
      if char.toString() is 'y'
        util.print 'Trying to clone...'.magenta
        try
          child = run_cmd
            cmd: ['git', 'clone', "git@github.com:RallySoftware/#{repo_name}.git"]
            cwd: "#{process.env.HOME}/projects"
            env: GET_ENV()
        catch e
          util.print "error cloning repo #{repo_name}".red, e

        child.on 'close', ->
          util.print 'Cloned!'.green
          resolve CURRENT_ENV
          promise = start_task task_name, GET_OPTS_FOR_TASK(task_name, CURRENT_ENV)

      else
        util.print 'Not cloning'.magenta
        resolve CURRENT_ENV

start_progress_indicator = ->
  fn = ->
    rl.clearLine process.stdout, 0
    process.stdout.write ' . '

  timer = setInterval fn, 300

  _.once ->
    clearInterval timer


############ / cloning shit ############

ZSHMIN =
  '''ZSH=$HOME/.oh-my-zsh
ZSH_CUSTOM=$HOME/.oh-my-zsh-custom
ZSH_THEME="git-taculous"
plugins=(emacs java alm appsdk git gls rally)
source $ZSH/oh-my-zsh.sh
export TERM=xterm-256color'''

module.exports = {
  get_debug: -> DEBUG
  set_debug
  _log
  error
  log_error
  log_proc_error
  prefix_pipe_output
  print
  trim
  color_array
  regex_extract
  clone_apply
  pipe_with_prefix
  get_color_fn
  get_hostname
  wait_for_keypress
  try_to_clone
  pretty_command_str
  beautify_obj
  object_map
  print_process_status
  kill_tree
  start_progress_indicator
  }
