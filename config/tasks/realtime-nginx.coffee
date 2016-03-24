module.exports = (env) ->
  name: 'realtime-nginx'
  alias: 'rn'
  command: ['realtime-nginx']
  start_message: "on #{'rally.dev:8999'.magenta}."
  cwd: "#{env.ROOTDIR}/burro"
  wait_for: /Started/
  is_running: ->
    run_cmd
      cmd: ["ps -ax | grep -v grep |  grep realtime-nginx-conf"]
      cwd: @cwd
      pipe_output: false
    .on_close.then ([code, signal]) ->
      code is 0

  exit_command: ['nginx', '-s', 'stop']
  callback: (data, env) ->
    [match, pid, nginx_conf] = data
    env
