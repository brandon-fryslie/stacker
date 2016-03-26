_ = require 'lodash'
fs = require 'fs'
# Gets + Checks ALM Schema name

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

die = (msg...) ->
  console.log.apply @, msg
  process.exit 1

get_schema_name = _.memoize ->
  try # Get schema name from .gradle/alm.groovy
    groovy_file = fs.readFileSync "#{process.env.HOME}/.gradle/alm.groovy", 'utf8'
    active_profile = regex_extract /active\s*=\s*(\w+)/, groovy_file
    schema_name = regex_extract ///#{active_profile}\s+{[\s\S]+?System\.env\.DB_NAME\s+\?:\s+['"]([^'"]+?)['"]///, groovy_file
  catch e

  if not groovy_file
    die 'Error: Could not find ~/.gradle/alm.groovy'

  if schema_name is 'indy' or schema_name is 'spoonpairing'
    die 'Error: make sure your schema name is not indy or spoonpairing.  Those are special schemas, people will be unhappy if they get broken'

  if "#{schema_name}".length < 1
    die 'Error: schema name is empty'

  schema_name

module.exports =
  args:
    ROOTDIR:
      describe: 'the root directory for projects'
      default: "#{process.env.HOME}/projects"
    burro_address:
      default: 'http://localhost:8855'
    zookeeper_address:
      alias: 'zk'
      describe: 'zookeeper address'
      default: 'bld-zookeeper-01:2181,bld-zookeeper-02:2181,bld-zookeeper-03:2181'
    schema:
      describe: 'pass in an alm schema name'
      default: get_schema_name()
