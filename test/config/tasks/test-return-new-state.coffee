module.exports = (state) ->
  name: 'Return new state'
  command: 'echo "It\'s easy!"'
  start_message: 'Testing returning a new state object...'
  wait_for: /.?/
  callback: (state, data) ->
    state.test_data = 'just some passed thru test data'
    here: 'is some new state for ya'
