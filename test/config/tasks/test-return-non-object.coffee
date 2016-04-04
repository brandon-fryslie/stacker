module.exports = (state) ->
  name: 'Return a non object in callback'
  command: 'echo AHHHHH!!!!'
  start_message: 'Testing returning a non object from callback'
  wait_for: /\s?/
  args:
    nonobject:
      default: 'its a thing!'
  callback: (state, data) ->
    null
