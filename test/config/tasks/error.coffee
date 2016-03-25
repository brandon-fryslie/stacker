module.exports = (state) ->
  name: 'Error'
  command: ['tail', '-f', 'non-existent-file.coffee']
  start_message: 'test error'
  wait_for: /Peace in the middle east/
  callback: (a,b,c) ->
    repl_lib.print 'error'
    repl_lib.print a,b,c
