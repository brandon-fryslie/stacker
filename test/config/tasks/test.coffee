module.exports = (env) ->
  name: 'Test'
  alias: 't'
  shell_env:
    KAFKA_QUEUE_TYPE: 'NIGHTMARE'
  command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
  start_message: 'Testing a basic task...'
  wait_for: /stacker/
