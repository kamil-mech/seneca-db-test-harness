
var spawn = require('child_process').spawn
var fs    = require('fs')
var util  = require('util')
var _     = require('lodash')

var cplabel = process.argv[2].split('.')[0].split('/')[1];
var argv  = process.argv.splice(2, process.argv.length)

var logfile  = __dirname + '/../log/' + cplabel + '.log'
var finfile  = __dirname + '/../log/' + cplabel + '.fin'
var errfile  = __dirname + '/../log/' + cplabel + '.err'

// run
argv.unshift(__dirname + '/pop.js');
var cp = spawn('node', argv);

output('\nBooting ' + cplabel)
output('\nPID: ' + cp.pid + '\n\n')

// forward output
cp.stdout.on('data', function (data) {
  output(data)
  if (data.toString().toLowerCase().indexOf('error') > -1) error(data)
})

// error handler
cp.stderr.on('data', function (data) {
  if (data.toString().indexOf('deprecated') === -1) {
    output(data)
    error(data)
  }
})

// on close
cp.on('close', function (code) {
  var msg = 'child process exited with code ' + code
  output(msg)
})

// on shutdown
process.on('exit', function (){
  fs.writeFileSync(finfile, '')
})

process.on('SIGINT', function () {
  fs.writeFileSync(finfile, '')
  process.exit(0);
})

// ---------------------------------------------------------------------

function error(data) {
  output('\nError detected: ' + data)
  output('\nLogfile can be found in: ' + logfile + '\n\n')
  fs.appendFileSync(errfile, data)
}

function output(data) {
  process.stdout.write(data)
  fs.appendFileSync(logfile, data)
}