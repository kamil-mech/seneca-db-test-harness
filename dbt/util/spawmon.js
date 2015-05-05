
var spawn = require('child_process').spawn
var fs    = require('fs')
var util  = require('util')

var argv  = process.argv.splice(2, process.argv.length)
var base  = argv[0]
var argv  = argv.splice(1, argv.length)

var filepath = argv[0]
var label = get_label(filepath)
var logfile = __dirname + '/log/' + label + '.log'
var finfile = __dirname + '/log/' + label + '.fin'
var errfile = __dirname + '/log/' + label + '.err'

// run
var cp    = spawn(base, argv)

output('\nBooting ' + label)
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
process.on('exit', function (){
  fs.writeFileSync(finfile, '')
})

// ---------------------------------------------------------------------

function error(data) {
  output('\nError detected: ' + data)
  output('Logfile can be found in: ' + __dirname + 'log/' + label + '.log\n\n')
  fs.appendFileSync(errfile, data)
}

function output(data) {
  process.stdout.write(data)
  fs.appendFileSync(logfile, data)
}

function get_label(path) {
  var path = path.split('/')
  file = path.pop()

  var temp = ''
  path.forEach(function(elem){
    temp += elem + '/'
  })

  path = temp + 'log/'

  // ensure log folder
  if (!fs.existsSync(path)) fs.mkdirSync(path)

  var index = 0
  var label = '[' + index + ']' + file
  while (true) {
    if (!fs.existsSync(path + label + '.log')) break
    else {
      label = '[' + index + ']' + file
      index++
    }
  }
  
  return label
}