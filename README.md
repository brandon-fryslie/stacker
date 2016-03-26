
stacker is a utility to run a bunch of processes at once

### usage

    stacker [tasks] [options]

### Getting started

Stacker is a useful tool to run multiple processes.  

To configure stacker, first you make a configuration directory.  The default location is ~/.stacker.

In this directory, make a directory called 'tasks'.  This is where task-specific configuration files are located.

Stacker will read all files in this directory and load the task configurations.

Here is an example configuration:

```coffee-script
module.exports = (state) ->
  name: 'Test'
  alias: 't'
  shell_env:
    KAFKA_QUEUE_TYPE: 'NIGHTMARE'
  command: ['tail', '-f', "#{process.env.HOME}/projects/rally-stack/bin/stacker"]
  args:
    'task-argument':
      describe: 'one hell of an argument'
      default: 'such a good default'
  start_message: 'Testing a basic task...'
  wait_for: /(stacker)/
  callback: (state, data) ->
    state.test_data = 'just some passed thru test data'
    here: 'is some new state for ya'
```

Your configuration file must be a common.js module that returns a function.  The function takes two optional arguments, the stacker state and a utility object.

The stacker state is the current internal state of stacker including args from the command line and from your config file.

The utility object contains some useful functions:

##### _

a reference to lodash version 4

##### print

print to the console from your commands with a 'stacker: ' prefex

### Concepts

#### Tasks

A 'task' is a process that you would like to run with stacker.


A 'task' is a process that you would like to run with stacker.  To create a task, include a task config in the 'tasks' directory of your stacker config directory.

Tasks consist of some parameters such as
the shell command needed to start the task, additional shell environment variables needed
for the task, and the working directory for the task.

Stacker will kill all running tasks when stacker exits.

#### Daemons

Daemons are a special type of task that represents a process that runs in the background.

Daemons require more configuration than tasks.  You must provide functions to tell stacker if the daemon is currently running,
and you must tell stacker how to shut the daemon down.

Stacker will attempt to detect if a daemon is already running before it tries to start it again, unless the --ignore-running-daemons flag is passed.

Daemons may be running when stacker starts, and they will not be shutdown automatically when stacker exits.

### Stacker state

The stacker state is the internal of the stacker tool.  It keeps track of arguments from your configuration files and from the command line.

Tasks can modify this state in the callbacks they define by returning an object to merge into the stacker state.

### CLI Options

CLI Options can be defined in several places.  They will be used to initialize stacker's state.

Command line arguments will be merged into stacker's state.  
They do not need to be explicitly defined, but it's probably a good idea to do so anyway.

Command line arguments specified by alias will merge only the full argument name into the state.

Command line arguments will automatically have hyphens (-) converted to underscores (\_) internally (e.g. '--my-cli-argument foo' becomes 'my_cli_argument: foo').  This is because the underscore variant is easier to represent in JavaScript (i.e. in your task config), while the hyphen variant is more common for command line interfaces.  They are functionally equivalent in Stacker.  You can define your configs with either variant, and specify either variant on the command line.  The help documentation will always display the hyphenated version, while the stacker state will always contain the underscored version.

#### Stacker CLI Options

##### ignore-running-daemons

stacker will attempt find daemon processes that are already running, unless you specify this option

##### help

print out the help.  Shows you which tasks stacker found, and any command line argument definitions stacker found in the config file or in task definitions.

#### Config CLI Options

You can define CLI options in your configuration file.

#### Task CLI Options

You can define CLI options in each individual task file as well.

### Debugging

Stacker allows you to enable debugging on a per-file basis.  Passing `--debug` on the command line will enable debuggin in all files.
Otherwise, pass the filename (without extension) to the debug command line argument.

e.g. `--debug task_config`

### testing

Tests are located in ./test.

Yu must have Mocha: `npm install -g mocha`

Then, run these commands:

```
cd ~/projects/rally-stack/stacker
npm test
```
