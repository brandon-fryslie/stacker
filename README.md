
stacker is a utility to run a bunch of processes at once

### usage

    stacker [tasks] [options]

    Options
       --zk                       Zookeeper Address
       --clean-alm                Clean ALM javas
       --dbm                      Run ALM DB Migrations task when starting ALM
       --with-local-appsdk        Use local appsdk at ~/projects/appsdk
       --with-local-app-catalog   Use local app-catalog at ~/projects/app-catalog
       --with-local-churro        Use local churro at ~/projects/churro
       -q, --quiet                Suppress output from processes
       --no-repl                  do not start repl
       --schema                   specify oracle schema name
       --bag-boy-profile          specify a lein profile for bag-boy
       --birdseed-profile         specify a lein profile for birdseed
       --pigeon-profile           specify a lein profile for pigeon

### common invocations

start lots of things

    stacker marshmallow zuul bag-boy birdseed alm pigeon --with-local-appsdk

use aliases

    stacker m z bb bs a p --with-local-churro

### options

ignore-running-daemons

stacker will find daemon processes that are already running, unless you specify this option

Useful for a docker container when you know nothing else is running and you want
to skip the is_running check

### concepts

#### task

a 'task' is a small piece of configuration that tells stacker how to run a piece of software.
They consist of some parameters such as
the shell command needed to start the task, additional shell environment variables needed
for the task, and the working directory for the task.

There are two kinds of tasks, regular tasks and background (daemon) tasks.

#### tasks

These guys stay in the foreground and print stuff to stdout.  They correspond to
individual system processes that stacker starts and keeps track of.   They will all
be terminated when stacker is shut down.


#### daemon task

Daemon tasks run in the background.  A daemon task configuration will tell stacker
how to start it, how to kill it, and importantly, how to know if it is already running.

Stacker will detect if a daemon is already running before it tries to start it again
(unless the --ignore-running-daemons flag is passed).

Stacker will not kill running daemons when stacker is closed.

Important: consider what dependencies you include in your daemon task.
Use --ignore-running-daemons to skip all checks to see if the daemon is running.

### adding a task

Tasks are coffee-script maps defined in task_config.coffee

Here is an example

```coffee-script
name: 'Birdseed'
alias: 'bs'
command: command
cwd: "#{rally.ROOTDIR}/birdseed"
additional_env:
  ZOOKEEPER_CONNECT: env.zookeeper_address
  BIRDSEED_SCHEMAS: env.schema
wait_for: /Hey little birdies, here comes your seed|(Connection timed out)/
callback: (data, env) ->
  [match, timeout_error] = data
  if timeout_error
    util.error 'Error: Birdseed failed to connect to Marshmallow', data.input ? data
  env
```

