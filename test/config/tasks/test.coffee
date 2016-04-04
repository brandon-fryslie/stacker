module.exports = (state) ->
  name: 'Test'
  alias: 't'
  shell_env:
    KAFKA_QUEUE_TYPE: 'NIGHTMARE'
  command: ['tail', '-f', "/etc/hosts"]
  args:
    task_argument:
      describe: 'one hell of an argument'
      default: 'such a good default'
  start_message: 'Testing a basic task...'
  wait_for: /(localhost)/
  callback: (state, data) ->
    state.test_data = 'just some passed thru test data'
    state
