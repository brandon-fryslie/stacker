module.exports = (state) ->
  name: 'Error'
  command: ['tail', '-f', 'non-existent-file.coffee']
  start_message: 'test error'
  wait_for: /Peace in the middle east/
  callback: (a,b,c) ->
    util.print 'error'
    util.print a,b,c
