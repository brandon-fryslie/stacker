PROCS = {}
DAEMONS = {}

module.exports =

  add_proc: (id, proc) -> PROCS[id] = proc

  remove_proc: (id) -> delete PROCS[id]

  all_procs: -> PROCS

  get_proc: (id) -> PROCS[id]

  add_daemon: (id, daemon) -> DAEMONS[id] = daemon

  remove_daemon: (id) -> delete DAEMONS[id]

  all_daemons: -> DAEMONS

  get_daemon: (id) -> DAEMONS[id]
