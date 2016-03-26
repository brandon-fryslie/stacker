require 'colors'
_  = require 'lodash'
task_config = require('./task_config').get_task_configs()
config = require './config_lib'
util = require './util'

# do a substitution on all keys in an object
replace_keys = (obj, pattern, replacement) ->
  util.object_map obj, (k, v) ->
    k = k.replace(pattern, replacement)
    "#{k}": v

# These come from files in CONFIG_DIR/tasks
task_cli_options = _(task_config).map('args').compact().value()

# These come from CONFIG_DIR/config.coffee
config_cli_options = config.get_config().args ? {}

stacker_cli_options =
  'debug':
    describe: 'turn on debug mode'
    default: false
  'no-repl':
    describe: 'do not start repl'
    default: false
  'ignore-running-daemons':
    describe: 'skip all is_running checks on daemons'
    default: false

cli_options = _.merge.apply _, task_cli_options.concat [config_cli_options, stacker_cli_options]

# convert '_' to '-' here for printing out the args
cli_options = replace_keys cli_options, /_/g, '-'

baked_yarg = require('yargs')
  .usage "#{'Usage:'.yellow} #{'stacker'.magenta} #{ "#{Object.keys(task_config).join(' ')} ".cyan}#{'[options]'.green }"
  .example "#{'stacker'.magenta} #{'marshmallow zuul burro alm pigeon'.cyan} #{'--with-local-churro'.green}", 'start the realtime stack with local churro'
  .updateStrings
    'Options:': 'Options:'.green
  .option 'help',
    alias: 'h'
    describe: 'show help message'
  .options cli_options
  .epilog '☃'.bold
  .wrap null

{argv} = baked_yarg

if argv.help
  baked_yarg.showHelp 'log'
  process.exit 0

if argv.debug
  util.set_debug()

# Set 'undefined' args to null so they are preserved in the stacker state
nullify_args = (argv, opt) ->
  for k, v of opt
    argv[k] = null if _.isUndefined(argv[k])

nullify_args(argv, opt) for opt in task_cli_options
nullify_args argv, config_cli_options
nullify_args argv, stacker_cli_options

# convert '-' to '_' in arguments for ease of writing tasks
argv = replace_keys argv, /-/g, '_'

# we omit these keys and all aliases from the stacker state
aliases = _(cli_options).map('alias').compact().value()
argv.stacker_state = _.omit argv, ['_', '$0', 'h', 'help'].concat aliases

# TODO: use task_cli_options to group the command line args

module.exports = argv
