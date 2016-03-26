
var spawn = require('child_process').spawn
var fs = require('fs')
var _ = require('lodash')

var rimraf = require('rimraf')
var cplabel = 'dbt-manager'

var logfile = __dirname + '/log/dbt-manager/' + cplabel + '.log'
var finfile = __dirname + '/log/dbt-manager/' + cplabel + '.fin'
var errfile = __dirname + '/log/dbt-manager/' + cplabel + '.err'

rimraf('log/', function () {
  fs.mkdirSync('log/')
  rimraf('/log/dbt-manager/', function () {
    fs.mkdirSync('log/dbt-manager/')

    // run
    var argv = process.argv.splice(2, process.argv.length)
    argv.unshift(__dirname + '/sdbth.js')
    var cp = spawn('node', argv)

    output('\nBooting ' + cplabel)
    output('\nPID: ' + cp.pid + '\n\n')

    // forward output
    cp.stdout.on('data', function (data) {
      output(data)
      if (data.toString().toLowerCase().indexOf('error') > -1) error(data)
    })

    // error handler
    cp.stderr.on('data', function (data) {
      output(data)
      error(data)
    })

    // on close
    cp.on('close', function (code) {
      var msg = 'child process exited with code ' + code
      output(msg)
    })

    // on shutdown
    process.on('exit', function () {
      fs.writeFileSync(finfile, '')
    })

    process.on('SIGINT', function () {
      fs.writeFileSync(finfile, '')
    })

    // ---------------------------------------------------------------------

    function error (data) {
      fs.appendFileSync(errfile, data)
    }

    function output (data) {
      process.stdout.write(data)
      fs.appendFileSync(logfile, data)
    }
  })
})
