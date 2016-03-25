module.exports =
  args:
    ROOTDIR:
      describe: 'root directory at which to find projects'
      default: "#{process.env.HOME}/projects"
    'config-argument':
      describe: 'good config arg'
      default: 'wonderful argument'
