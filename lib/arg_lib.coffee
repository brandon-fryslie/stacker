require 'colors'
_  = require 'lodash'
util = require './util'

# require all the debug first
debug_opts = require('yargs')(process.argv)
  .options debug: type: 'array'
  .argv

debug_opts.debug = true if debug_opts.debug?.length is 0
util.set_debug(debug_opts.debug) if debug_opts.debug
# /debug

task_configs = require('./task_config').get_task_configs()
config = require './config_lib'

# do a substitution on all keys in an object
replace_keys = (obj, pattern, replacement) ->
  util.object_map obj, (k, v) ->
    k = k.replace(pattern, replacement)
    "#{k}": v

# These come from CONFIG_DIR/tasks
task_cli_options = _(task_configs).values().map('args').compact().value()

# These come from CONFIG_DIR/config.coffee
config_cli_options = config.get_config().args ? {}

stacker_cli_options =
  debug:
    describe: 'turn on debug mode'
    type: 'array'
  repl:
    describe: 'start stacker repl'
    default: true
    type: 'boolean'
  ignore_running_daemons:
    describe: 'skip all is_running checks on daemons'
    default: false

cli_options = _.merge.apply _, task_cli_options.concat [config_cli_options, stacker_cli_options]

# convert '_' to '-' here for printing out the args
cli_options = replace_keys cli_options, /_/g, '-'

baked_yarg = require('yargs')(process.argv.slice(2))
  .usage "#{'Usage:'.yellow} #{'stacker'.magenta} #{ Object.keys(task_configs).join(' ').cyan}#{'[options]'.green }"
  .example "\nstacker config dir: #{process.env.STACKER_CONFIG_DIR}\n\n#{'stacker'.magenta} #{'marshmallow zuul burro alm pigeon'.cyan} #{'--with-local-churro'.green}", 'start the realtime stack with local churro'
  .updateStrings
    'Options:': 'Options:'.green
  .option 'help',
    alias: 'h'
    describe: 'show help message'
  .options cli_options
  .epilog '☃'.bold
  .wrap null # turns off automatic line wrapping

{argv} = baked_yarg

if argv.help
  baked_yarg.showHelp 'log'
  process.exit 0

if not argv.debug?
  delete argv.debug
else if argv.debug.length is 0
  argv.debug = true

# Set 'undefined' args to null so they are preserved in the stacker state
util.object_map argv, (k, v) ->
  argv[k] = null if _.isUndefined(argv[k])

# convert '-' to '_' in arguments for ease of writing tasks
argv = replace_keys argv, /-/g, '_'

# we omit these keys and all aliases from the stacker state
aliases = _(cli_options).map('alias').compact().value()
argv.stacker_state = _.omit argv, ['_', '$0', 'h', 'help', 'repl'].concat aliases

# TODO: use task_cli_options to group the command line args

module.exports.args = argv
