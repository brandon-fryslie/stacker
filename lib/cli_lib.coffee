require 'colors'
_  = require 'lodash'
task_config = require('./task_config_lib').get_task_configs()
config = require './config_lib'
util = require '../util/util'

stacker = 'stacker'.magenta

set_yarg_opt = (opt) ->
  for key, value of opt
    yarg.option key, value

task_cli_options = _(task_config).map('args').compact().value()

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

yarg = require('yargs')
  .usage "#{'Usage:'.yellow} #{stacker} #{ "#{Object.keys(task_config).join(' ')} ".cyan}#{'[options]'.green }"
  .example "#{stacker} #{'marshmallow zuul burro alm pigeon'.cyan} #{'--with-local-churro'.green}", 'start the realtime stack with local churro'
  .updateStrings
    'Options:': 'Options:'.green
  .option 'help',
    alias: 'h'
    describe: 'show help message'

task_cli_options.map set_yarg_opt
set_yarg_opt config_cli_options
set_yarg_opt stacker_cli_options

baked_yarg = yarg
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

argv.stacker_env = _.omit argv, ['_', '$0', 'h', 'help']

# TODO: use task_cli_options to group the command line args

module.exports = argv
