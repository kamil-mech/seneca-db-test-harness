
var spawn = require('child_process').spawn
var fs = require('fs')
var _ = require('lodash')

var cplabel = process.argv[2].split('.')[0].split('/')[1]
var argv = process.argv.splice(2, process.argv.length)

var logfile = __dirname + '/../log/' + cplabel + '.log'
var finfile = __dirname + '/../log/' + cplabel + '.fin'
var errfile = __dirname + '/../log/' + cplabel + '.err'

// run
argv.unshift(__dirname + '/pop.js')
var cp = spawn('node', argv)

// get config
var info = fs.readFileSync(argv[1])
info = JSON.parse(info)

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
  process.exit(0)
})

// ---------------------------------------------------------------------

function error (data) {
  if (!justWarning(data)) {
    output('\nError detected: ' + data, true)
    output('\nLogfile can be found in: ' + logfile + '\n\n', true)
    fs.appendFileSync(errfile, data)
  }
}

function justWarning (data) {
  var knownWarnings = ['warning', 'deprecated', 'aborted connection',  'unable to find image ', 'latest: pulling from', ': pulling fs layer', ': waiting', ': download complete', ': verifying checksum']
  var lowdata = data.toString().toLowerCase()
  var justWarning = false
  _.each(knownWarnings, function (warning) {
    if (!justWarning && lowdata.indexOf(warning) > -1) justWarning = true
  })
  return justWarning
}

function output (data, forcePrint) {
  if (forcePrint || !info.flags.nwo) process.stdout.write(data)
  fs.appendFileSync(logfile, data)
}
