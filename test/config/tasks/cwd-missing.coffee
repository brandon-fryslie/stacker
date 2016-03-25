module.exports = (state, util) ->
  name: 'Error'
  command: ['echo', 'pillow']
  cwd: '/bla/bla/bla'
  start_message: 'test missing cwd'
  callback: (a,b,c) ->
    util.print 'error'
    util.print a,b,c
