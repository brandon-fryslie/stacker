module.exports = (state) ->
  name: 'Test2'
  alias: 't2'
  command: ['echo running test2!']
  start_message: "test2 here, checking test data: #{state.test_data}"
  wait_for: /running test2/
