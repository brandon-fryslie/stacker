module.exports = (state) ->
  name: 'Return new state'
  command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
  start_message: 'Testing returning a new state object...'
  wait_for: /(stacker)/
  callback: (state, data) ->
    state.test_data = 'just some passed thru test data'
    here: 'is some new state for ya'
