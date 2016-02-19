_ = require 'lodash'
fs = require 'fs'
require 'colors'
repl_lib = require './lib/repl_lib'
util = require './util/util'

# Constants
ROOTDIR = "#{process.env.HOME}/projects"
DEFAULT_BURRO_ADDRESS = 'http://localhost:8855'
BLD_ZOOKEEPER_ADDRESS = 'bld-zookeeper-01:2181,bld-zookeeper-02:2181,bld-zookeeper-03:2181'

WARNINGS = []

# Gets + Checks ALM Schema name
get_schema_name = _.memoize ->

  try # Get schema name from .gradle/alm.groovy
    groovy_file = fs.readFileSync "#{process.env.HOME}/.gradle/alm.groovy", 'utf8'
    active_profile = util.regex_extract /active\s*=\s*(\w+)/, groovy_file
    schema_name = util.regex_extract ///#{active_profile}\s+{[\s\S]+?System\.env\.DB_NAME\s+\?:\s+['"]([^'"]+?)['"]///, groovy_file
  catch e

  if not groovy_file
    util.die 'Error: Could not find ~/.gradle/alm.groovy'

  if schema_name is 'indy' or schema_name is 'spoonpairing'
    util.die 'Error: make sure your schema name is not indy or spoonpairing.  Those are special schemas, people will be unhappy if they get broken'

  if "#{schema_name}".length < 1
    util.die 'Error: schema name is empty'

  repl_lib.print "Found schema: #{schema_name.magenta}"

  schema_name

# Start these tasks
get_tasks_to_start = (tasks, opts) ->
  _.map(tasks, resolve_task_name)

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
  get_schema_name: get_schema_name
  get_tasks_to_start: get_tasks_to_start
  ROOTDIR: ROOTDIR
  DEFAULT_BURRO_ADDRESS: DEFAULT_BURRO_ADDRESS
  BLD_ZOOKEEPER_ADDRESS: BLD_ZOOKEEPER_ADDRESS
