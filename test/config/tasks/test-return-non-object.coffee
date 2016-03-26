module.exports = (state) ->
  name: 'Return a non object in callback'
  command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
  start_message: 'Testing returning a non object from callback'
  wait_for: /(stacker)/
  args:
    nonobject:
      default: 'its a thing!'
  callback: (state, data) ->
    null
