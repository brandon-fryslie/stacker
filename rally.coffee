_ = require 'lodash'
fs = require 'fs'
require 'colors'
repl_lib = require './lib/repl'
util = require './util/util'

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
  get_tasks_to_start: get_tasks_to_start
