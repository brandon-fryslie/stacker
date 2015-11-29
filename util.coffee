_ = require 'lodash'
require 'colors'
stream = require 'stream'
os = require 'os'

# print something with a prefix
prefix_print = (prefix, str...) ->
  str.splice 0, 0, prefix

  str = for s in str
    "#{s}".split('\n').join("\n#{prefix} ")

  console.log.apply @, str

# exposed function for printing messages from stacker itself
repl_print = (str...) ->
  str.unshift 'stacker:'.bgWhite.black
  prefix_print.apply @, str

# kills the whole shebang.  probably don't use @
die = (msg...) ->
  msg = color_array msg, 'red'
  repl_print 'YOU DED'.red
  repl_print.apply @, msg
  process.exit 1

# throw exception and print error
error = (msg...) ->
  log_error.apply @, msg
  throw new Error msg

# only print error
log_error = (msg...) ->
  msg = color_array msg, 'red'
  repl_print.apply @, msg

log_proc_error = (err) ->
  msg = switch err.code
    when 'ENOENT' then "File not found"
    when 'EPIPE' then "Writing to closed pipe"
    else err.code

  log_error "Error: #{task_name} #{err.code} #{msg}"

# color an array of strings
color_array = (array, color) ->
  for s in array
    if typeof s is 'string' and s[color] then s[color] else s

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
      @push "#{prefix} #{line}\n"

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

get_hostname = _.memoize -> os.hostname()

module.exports =
  die: die
  error: error
  log_error: log_error
  log_proc_error: log_proc_error
  prefix_pipe_output: prefix_pipe_output
  repl_print: repl_print
  trim: trim
  color_array: color_array
  regex_extract: regex_extract
  clone_apply: clone_apply
  pipe_with_prefix: pipe_with_prefix
  get_color_fn: get_color_fn
  get_hostname: get_hostname