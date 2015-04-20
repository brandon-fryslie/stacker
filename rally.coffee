_ = require 'lodash'
fs = require 'fs'
require 'colors'
repl_lib = require './repl'
util = require './util'

# Constants
ROOTDIR = "#{process.env.HOME}/projects"
DEFAULT_BURRO_ADDRESS = 'http://localhost:8855'

WARNINGS = []

# Gets + Checks ALM Schema name
get_schema_name = ->

  # Get schema name from .gradle/alm.groovy
  try
    groovy_file = fs.readFileSync "#{process.env.HOME}/.gradle/alm.groovy", 'utf8'
    groovy_schema_name = util.regex_extract /System\.env\.DB_NAME \?: '([^']+)'/, groovy_file
  catch e
    repl_lib.print "Did not find file #{"#{process.env.HOME}/.gradle/alm.groovy"}\n".yellow

  # Get schema name from .m2/settings.xml
  try
    m2_file = fs.readFileSync "#{process.env.HOME}/.m2/settings.xml", 'utf8'
    active_profile = util.regex_extract /\<activeProfile\>([^<]+)<\/activeProfile>/, m2_file
    m2_schema_name = util.regex_extract ///<id>#{active_profile}</id>[\s\S]*?<dbname>([^<]+)</dbname>///, m2_file
  catch e
    repl_lib.print "Did not find file #{"#{process.env.HOME}/.m2/settings.xml"}".yellow

  if not groovy_file and not m2_file
    util.die 'Error: Could not find either groovy file or m2 file'

  if m2_schema_name? and groovy_schema_name? and (m2_schema_name isnt groovy_schema_name)
    util.die "Error: schema in .m2/settings.xml #{m2_schema_name} doesn't match schema in .gradle/alm.groovy #{groovy_schema_name}.  This can cause problems I don't quite remember"

  schema_name = groovy_schema_name

  if schema_name is 'indy' or schema_name is 'spoonpairing'
    util.die 'Error: make sure your schema name is not indy or spoonpairing.  Those are special schemas, people will be unhappy if they get broken'

  if "#{schema_name}".length < 1
    util.die 'Error: schema name is empty'

  repl_lib.print "Found schema: #{schema_name.blue.bold}"

  schema_name

# Start these tasks
get_tasks_to_start = (tasks, opts) ->
  tasks = _.map(tasks, resolve_task_name)

  if opts['with-local-churro'] && !_.contains(tasks, 'burro')
    indexOfAlm = tasks.indexOf('alm')
    if indexOfAlm > -1
      tasks.splice(indexOfAlm, 0, 'burro')

  tasks

# Shorthands for service names
resolve_task_name = (name) ->
  {
    a:  'alm'
    b:  'burro'
    bb: 'bag-boy'
    bs: 'birdseed'
    m:  'marshmallow'
    p:  'pigeon'
    z:  'zuul'
  }[name] || name

module.exports =
  get_schema_name: get_schema_name()
  get_tasks_to_start: get_tasks_to_start
  resolve_task_name: resolve_task_name
  ROOTDIR: ROOTDIR
  DEFAULT_BURRO_ADDRESS: DEFAULT_BURRO_ADDRESS
