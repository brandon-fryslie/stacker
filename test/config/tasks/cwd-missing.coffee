module.exports = (state) ->
  name: 'Error'
  command: ['echo', 'pillow']
  cwd: '/bla/bla/bla'
  start_message: 'test missing cwd'
  callback: (a,b,c) ->
    repl_lib.print 'error'
    repl_lib.print a,b,c
