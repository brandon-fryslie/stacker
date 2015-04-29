require 'colors'
stream = require 'stream'

# Utilities
die = (msg...) ->
  msg = color_array msg, 'red'
  console.log 'YOU DED'.red
  console.log.apply this, msg
  process.exit 1

error = (msg...) ->
  log_error.apply this, msg
  throw new Error msg

log_error = (msg...) ->
  msg = color_array msg, 'red'
  console.log.apply this, msg

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
##########################################
#  / stream coloring
##########################################

# extract first capture group from regex
# (regex, string) -> string
regex_extract = (regex, str) ->
  data = regex.exec str
  unless data
    die 'Could not find match in', regex, str
  [match, group1] = data
  unless group1
    die 'Could not find match for group in', regex, str
  group1

clone_apply = (obj1, obj2) ->
  newObj = {}
  newObj[k] = v for k, v of obj1
  newObj[k] = v for k, v of obj2
  newObj

trim = (s) -> s.replace /(^\s*)|(\s*$)/g, ''

module.exports =
  die: die
  error: error
  log_error: log_error
  trim: trim
  color_array: color_array
  regex_extract: regex_extract
  clone_apply: clone_apply
  pipe_with_prefix: pipe_with_prefix
  get_color_fn: get_color_fn