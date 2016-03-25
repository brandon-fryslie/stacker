module.exports = (state) ->
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
  callback: (state, data) ->
    state.test_data = 'just some passed thru test data'
    here: 'is some new state for ya'
