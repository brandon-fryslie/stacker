require 'colors'
nomnom = require 'nomnom'
rally = require './rally'
task_config = require './task_config'

opts = nomnom
.printer((str) ->
  console.log "\nUsage: stacker #{ "[#{Object.keys(task_config).join('] [')}] ".cyan} #{'[options]'.bold.green}\n"
  console.log 'Options'.bold.green
  console.log options_str = str.split('\n')[4..].join('\n')
  process.exit 0
)
.option('zk'
  help: 'Zookeeper Address'
)
.option('clean-alm'
  help: 'Clean ALM javas'
  flag: true
)
.option('dbm'
  help: 'Run ALM DB Migrations task when starting ALM'
  flag: true
)
.option('with-local-appsdk'
  help: 'Use local appsdk at ~/projects/appsdk'
  flag: true
)
.option('with-local-app-catalog'
  help: 'Use local app-catalog at ~/projects/app-catalog'
  flag: true
)
.option('with-local-churro'
  help: 'Use local churro at ~/projects/churro (starts burro too)'
  flag: true
)
.option('quiet'
  help: 'Suppress output from processes'
  abbr: 'q'
  flag: true
)
.option('no-repl'
  help: 'do not start repl'
  flag: true
)
.option('ignore-running-daemons'
  help: 'skip all is_running checks on daemons'
  flag: true
)
.option('schema'
  help: 'specify oracle schema name'
)
.option('bag-boy-profile'
  help: 'specify a lein profile for bag-boy'
)
.option('birdseed-profile'
  help: 'specify a lein profile for birdseed'
)
.option('pigeon-profile'
  help: 'specify a lein profile for pigeon'
)
.parse()

# nomnom is fucking stupid
opts['no-repl'] = opts.repl is false

module.exports = opts