module.exports = (env) ->
  name: 'Test'
  alias: 't'
  shell_env:
    KAFKA_QUEUE_TYPE: 'NIGHTMARE'
  command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
  args:
    'task-argument':
      describe: 'one hell of an argument'
      default: 'such a good default'
  start_message: 'Testing a basic task...'
  wait_for: /(stacker)/
  callback: (data, env) ->
    env.test_data = 'just some passed thru test data'
    env
