'use strict'

var file = process.argv[2]
var fs = require('fs')
var util = require('util')
var proc = require('child_process')
var async = require('async')
var _ = require('lodash')

var Docker = require('docker-cmd')
var docker = new Docker()
var terminal = require(__dirname + '/terminal.js')

var isPulling = false

console.log('file: ' + file)

var info

try {
  info = fs.readFileSync(file)
  info = JSON.parse(info)
} catch (err) {
  throw err
}

console.log('conf: ' + util.inspect(info))

var dbconst = info.db.dbconst
var calls
if (info.launchType === 'db') {
  terminal.setTitle(info.db.label)

  calls = []
  if (info.flags.fd) {
    calls.push(function (next) {
      fs.writeFileSync(__dirname + '/../temp/' + info.db.label + '.fds', 'fds') // signals pull start
      console.log('pulling docker image for ' + dbconst.image + '...')
      proc.exec('docker pull ' + dbconst.image, function (err, stdout, stderr) {
        if (err) console.log(err)
        if (stdout) console.log(stdout)
        if (stderr) console.log(stderr)
        fs.writeFileSync(__dirname + '/../temp/' + info.db.label + '.fde', 'fde')
        next()
      })
    })
  }

  // runscript or regular
  if (dbconst.run) {
    // runscript
    var cmdargs = []
    _.each(dbconst.reads, function (option) {
      cmdargs.push(info.db.options[option])
    })
    cmdargs.push(__dirname + '/../temp/' + info.db.label + '.cid') // cidfile
    cmdargs.unshift(__dirname + '/../dbs' + dbconst.run)
    calls.push(function (next) {
      console.log('cmdargs: ' + cmdargs)
      spawn('bash', cmdargs)
      next()
    })
  } else {
    // regular
    calls.push(function (next) {
      var cidfile = __dirname + '/../temp/' + info.db.label + '.cid'
      var cmdargs = []
      cmdargs.push('run')
      cmdargs.push('-p')
      cmdargs.push(dbconst.port + ':' + dbconst.port)
      if (dbconst.extra_ports) {
        _.each(dbconst.extra_ports, function (port) {
          cmdargs.push('-p')
          cmdargs.push(port + ':' + port)
        })
      }
      cmdargs.push('--name=' + info.db.name)
      cmdargs.push('--cidfile=' + cidfile)
      cmdargs.push(dbconst.image)
      spawn('docker', cmdargs)
      next()
    })
  }

  async.series(calls, function () {
    // init complete
  })
} else if (info.launchType === 'app') {
  terminal.setTitle(info.image.label)

  calls = []
  if (info.flags.fb) {
    calls.push(function (next) {
      console.log('rebuilding image ' + info.image.name)
      docker.build({_: info.image.path, t: info.image.name}, null, function (status) {
        fs.writeFileSync(__dirname + '/../temp/' + info.image.label + '.fb', 'fb')
        next()
      })
    })
  }
  setEnv(info)

  calls.push(function (next) {
    console.log('dbconst: ' + util.inspect(dbconst))
    var link = dbconst.local ? null : info.db.name
    var runobj = {_: info.image.name, name: info.image.label, e: 'db=' + info.db.name + '-store', cidfile: __dirname + '/../temp/' + info.image.label + '.cid'}
    if (link) runobj.link = link
    docker.run(runobj, null, function (status) {
      next()
    })
  })

  async.series(calls, function () {
    // init complete
  })
} else if (info.launchType === 'test') {
  var cid = fs.readFileSync(__dirname + '/../temp/' + info.imagecontainer.label + '.cid').toString()
  terminal.setTitle(info.testlabel)
  // setEnv(info)
  // spawn('bash', ['-c', 'cd ' + info.testpath + '; npm test --db=' + info.db.name + '-store --ip=' + info.imagecontainer.ip + ' --port=' + info.imagecontainer.port])
  spawn('bash', ['-c', 'docker exec -i ' + cid + ' bash -c "npm test --db=' + info.db.name + '-store"'])
}

function ignorePullingWarnings (data) {
  var changedJustNow = false

  if (data.toString().indexOf('Unable to find image') > -1) {
    fs.writeFileSync(__dirname + '/../temp/' + info.db.label + '.fds', 'fds') // signals pull start
    isPulling = true
  }
  else if (data.toString().indexOf('Status: Downloaded newer image for') > -1) {
    isPulling = false
    changedJustNow = true
    fs.writeFileSync(__dirname + '/../temp/' + info.db.label + '.fde', 'fde')
  }

  process.stdout.write(data)
  return (isPulling || changedJustNow) ? '' : data
}

function setEnv (info) {
  if (info.dbcontainer) {
    var env = info.db.name.toUpperCase() + '_PORT_' + info.dbcontainer.port + '_TCP_ADDR'
    console.log('Export ' + env + '=' + info.dbcontainer.ip)
    process.env[env] = info.dbcontainer.ip
  }
}

function spawn (cmd, args) {
  console.log()
  console.log('running ' + cmd + ' ' + args)
  console.log()
  var cp = proc.spawn(cmd, args)
  cp.stdout.on('data', function (data) {
    process.stdout.write(data)
  })
  cp.stderr.on('data', function (data) {
    data = ignorePullingWarnings(data)
    process.stdout.write(data)
  })
  cp.on('close', function (code) {
    console.log('child process exited with code ' + code)
  })
  return cp
}
