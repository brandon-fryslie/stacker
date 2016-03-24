module.exports = (env) ->
  name: 'Docker Oracle'
  alias: 'do'
  command: ['lein', 'start-docker-oracle']
  cwd: "#{env.ROOTDIR}/pigeon"
  shell_env:
    DEV_MODE: true

  exit_command: ['lein', 'stop-docker-oracle']
  # -> (Promise -> boolean)
  is_running: ->
    container_name = "dev-#{util.get_hostname().replace(/[\W]/g, '-')}-pigeon"

    util.repl_print "Looking for docker container #{container_name.cyan}..."

    mproc = run_cmd
      cmd: ["docker ps -a | grep #{container_name}"]
      cwd: @cwd
      env: @shell_env
      pipe_output: false

    mproc.on_close.then ([code, signal]) ->
      code is 0

  cleanup: ->
    container_name = "dev-#{util.get_hostname().replace(/[\W]/g, '-')}-pigeon"

    util.repl_print "Cleaning up docker container #{container_name}..."

    run_cmd
      cmd: ["docker ps -a | grep #{container_name} | awk '{print $1}' | xargs docker rm -f"]
      cwd: @cwd
      env: @shell_env
      pipe_output: false
    .on_close

  wait_for: /WRITING JDBC CONFIG|(Conflict)/
  callback: (data, env) ->
    [match, exception] = data
    if exception
      util.error 'Warning: Conflict trying to create new oracle docker container.  Delete the old one'.yellow, data.input ? data
    env
