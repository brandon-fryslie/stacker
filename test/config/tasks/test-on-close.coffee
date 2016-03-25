module.exports = (state) ->
  name: 'TestOnClose'
  command: ['./display-after-1-second.sh', 'Hi There!']
  cwd: "#{state.ROOTDIR}/rally-stack/stacker/etc"
  start_message: 'test close callback'
  wait_for: /The/
  onClose: (code, signal) ->
    run_cmd cmd: ['echo', 'Exit command successfully run!']
