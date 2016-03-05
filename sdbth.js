'use strict'

var util = require('util')
var _ = require('lodash')
var async = require('async')
var fs = require('fs')
var proc = require('child_process')

var rimraf = require('rimraf')
var DBC = require(__dirname + '/lib/check-db.js')
var dbc
var terminal = require(__dirname + '/lib/terminal.js')

var cleanedOnce = false // if cleaned at least once. Used for not spamming sudo requests

process.on('SIGINT', function () {
  cleanup(function () {
    process.exit(0)
  })
})

process.on('uncaughtException', function (err) {
  cleanup(function () {
    console.log('Uncaught exception: ' + err.stack)
    process.exit(1)
  })
})

var gargs = process.argv
gargs.shift()
gargs.shift()
var flags = {}
var extras = []
var dbs = []
var app = {}
var conf

var dbtIterations = []
var current = 0
var currentStep = 0
var failsSoFar = 0

var dbindices = {}
var imageindices = {}
var builtImages = {}

var currentdb // global

// preload
console.log('---------')
console.log('init')
cleanup(function () {
  terminal.setTitle('DBT Manager')
  rimraf('temp/', function () {

    processArgs()
    loadConf()

    // iterations
    _.each(dbs, function (dbname) {
      var iterations = 1
      var more = dbname.split('-')[1]
      if (more) iterations = parseInt(more, 10)
      if (iterations.toString() === 'NaN') throw new Error('invalid multipicity syntax at ' + dbname)
      dbname = dbname.split('-')[0]
      debugOut('dbname: ' + dbname + '. iterations: ' + iterations)

      // call each db test multiplicity times
      for (var i = 0; i < iterations; i++) {
        if (dbindices[dbname] === undefined) dbindices[dbname] = 0
        else dbindices[dbname]++
        dbtIterations.push(main.bind(null, {db: {name: dbname, index: dbindices[dbname]}}))
      }
    })
    // in series
    cleanup(function () {
      async.series(dbtIterations, function () {
        console.log('---------')
        console.log('final cleanup')
        summarize()
        console.log()
        process.kill(process.pid, 'SIGINT') // TODO remove
      })
    })
  })
})

function main (args, cb) {
  args.db.label = args.db.name + '--' + args.db.index
  current += 1
  currentStep = 0
  currentdb = args.db.label
  updateTerminalTitle()
  // main body
  console.log('---------')
  console.log('start ' + args.db.label)
  if (!fs.existsSync('temp/')) fs.mkdirSync('temp/')
  imageindices = {} // reset counter
  async.series([
    function (next) { rundb(args, next) },
    showProgress,
    function (next) { runapp(args, next) },
    showProgress,
    function (next) { runtest(args, next) },
    function (next) { monitor(args, next) },
    showProgress,
    cleanup,
    showProgress,
    function (next) { grabFiles(args, next) }
  ], function (err, res) {
    if (err) {
      console.error(err.stack + '\nSkip to next')
      // fs.appendFileSync(__dirname + '/log/dbt-manager.err', err.stack)
    }
    cleanup(function () {
      grabFiles(args, function () {
        console.log('end ' + args.db.label)
        return cb()
      })
    })
  })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function processArgs () {
  console.log()
  console.log('process args')

  debugOut('gargs: ' + gargs)
  if (_.isEmpty(gargs)) throw new Error('no args provided')

  app.name = gargs[0]
  gargs.shift()
  debugOut('app: ' + app.name)

  var popdbs = false
  _.each(gargs, function (arg) {
    if (arg.charAt(0) === ('-')) {
      if (arg === '-dbs') popdbs = true
      else popdbs = false

      arg = arg.substring(1)
      flags[arg] = true
    } else {
      if (popdbs) dbs.push(arg)
      else extras.push(arg)
    }
  })
  debugOut('flags: ' + util.inspect(flags))
  debugOut('extras: ' + extras)
  debugOut('dbs: ' + dbs)

}

// ----------------------------------------------------------------------------------------------------------------------------------------
function loadConf () {
  console.log()
  console.log('get conf from file')
  var confFile = __dirname + '/../sdbth.conf'
  if (!fs.existsSync(confFile)) throw new Error('no conf file found - create ' + confFile)
  conf = require(confFile)[app.name]
  if (!conf) throw new Error('definition for ' + app.name + ' not found in ' + confFile)
  _.each(['optionsfile', 'dockimages', 'deploymode'], function (field) {
    if (!conf[field]) throw new Error('no ' + field + ' provided in ' + confFile)
  })
  if (_.isEmpty(conf.dockimages)) throw new Error('no dockimages provided in ' + confFile)

  var optionsFile = conf.optionsfile
  debugOut('optionsFile: ' + optionsFile)

  var options = require(optionsFile)
  if (!options) throw new Error('options file not valid')
  debugOut('options: ' + util.inspect(options))
  app.options = options
}

function showProgress (next) {
  currentStep++
  updateTerminalTitle()
  if (next) return next()
}

function updateTerminalTitle () {
  var progressBar = ''
  for (var i = 0; i < currentStep; i++) progressBar += '||'
  while (progressBar.length < 12) progressBar += '  '
  terminal.setTitle('[' + progressBar + '] DBT Manager (' + current + '/' + dbtIterations.length + ') (' + failsSoFar + ' fails) ' + currentdb)
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function rundb (args, cb) {
  console.log()
  console.log('run db ' + args.db.name)
  debugOut('load db specific constants')
  try {
    var dbconst = fs.readFileSync('dbs/' + args.db.name + '.json')
    dbconst = JSON.parse(dbconst)
    args.db.dbconst = dbconst
    debugOut('dbconst: ' + util.inspect(dbconst))
  } catch (err) {
    if (err.message.indexOf('ENOENT') > -1) return cb(new Error('DB ' + args.db.name + ' is not supported'))
  }

  if (!dbconst.local) {
    var base = 'temp/' + args.db.label
    var infofile = base + '.json'
    // var logfile = base + '.log'
    var info = _.extend(args, {
      launchType: 'db',
      flags: flags
    })

    // ensure init options are in options file
    if (dbconst.init) {
      var opts = app.options[args.db.name + '-store']
      if (opts) {
        _.each(dbconst.reads, function (field) {
          if (!opts[field]) return cb(new Error(args.db.name + ' option ' + field + ' not found in options file'))
        })
        info.db.options = opts
      } else return cb(new Error(args.db.name + ' options not found in options file'))
    }

    debugOut('run db image & attach monitor')
    // pop a new terminal(gnome-terminal)
    newWindow(infofile, info)

    // wait for db
    waitPulled(args.db.label, flags.fd, function (res) {
      if (!res) return cb(new Error('Err while pulling docker image'))
      
      return pulled(cb)
    })
  } else return cb()

  function pulled (cb) {
    showProgress()
    // wait for docker container to be up
    var cidfile = 'temp/' + args.db.label + '.cid'
    if (info.db.options) info.db.options.dbcid = fs.readFileSync(cidfile)
    waitContainer(cidfile, 10, function (res) {
      if (!res) return cb(new Error('DB Container cidfile ' + cidfile + ' not found. Timed out while waiting for container'))
      proc.exec('docker inspect ' + args.db.name + ' >temp/' + args.db.label + '.conf', function (err, stdout, stderr) {
        if (err) return cb(err)
        debugOut('get db container info')
        var dbconf
        try {
          dbconf = fs.readFileSync('temp/' + args.db.label + '.conf')
          dbconf = JSON.parse(dbconf)
          dbconf = dbconf[0]
        } catch (err) {
          return cb(err)
        }
        debugOut('dbconf: ' + util.inspect(dbconf))
        var dbip = dbconf.NetworkSettings.IPAddress
        if (info.db.options) info.db.options.dbip = dbip
        debugOut('dbconfIP: ' + dbip)

        flags.fd = false
        waitReady(dbip, dbconst.port, args.db.label, function (res) {
          if (!res) return cb(new Error('Timed out while waiting for db'))

          setTimeout(function () {
            args.db.container = {
              label: args.db.label,
              ip: dbip,
              port: dbconst.port,
              cid: info.db.options.dbcid
            }
            if (dbconst.init) {
              // init script
              console.log('init ' + args.db.name)
              var cmdargs = []
              _.each(dbconst.reads, function (option) {
                cmdargs.push(info.db.options[option])
              })
              _.each(dbconst.computes, function (option) {
                cmdargs.push(info.db.options[option])
              })
              cmdargs.unshift(__dirname + '/dbs/' + dbconst.init)
              var cp = spawn('bash', cmdargs)
              cp.on('close', sanityCheck)
            } else return sanityCheck()
          }, 1000)

          function sanityCheck () {
            // sanity check
            console.log()
            console.log('run smoke test')
            var target = {
              db: args.db.name,
              host: dbip,
              port: dbconst.port,
              testargs: dbconst.testargs
            }
            dbc = DBC(target)
            dbc.check(function (err, res) {
              return cb(err, res)
            })
          }
        })
      })
    })
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function runapp (args, cb) {
  console.log()
  if (flags.na) {
    console.log('setup complete')
  } else {
    console.log('run app')

    var calls = []
    var iterator = 0
    _.each(conf.dockimages, function (image) {
      calls.push(runimg.bind(null, image, iterator * 30))
    })
    async[conf.deploymode](calls, cb)
  }

  function runimg (image, delay, cb) {
    setTimeout(function () {
      if (imageindices[image.name] === undefined) imageindices[image.name] = 0
      else imageindices[image.name]++
      image.label = image.name + '--' + imageindices[image.name]
      debugOut('image.label: ' + image.label)

      // pop a new terminal(gnome-terminal)
      var base = 'temp/' + image.label
      var infofile = base + '.json'
      // var logfile = base + '.log'
      var info = _.extend(args, {
        launchType: 'app',
        app: app,
        image: image,
        flags: flags,
        dbconst: args.db.dbconst
      })
      if (flags.fb && builtImages[image.name]) info.flags.fb = false
      debugOut('run app image ' + image.label + ' & attach monitor')
      newWindow(infofile, info)
      // wait for image
      debugOut('wait for app container')

      if (flags.fb && !builtImages[image.name]) {
        waitBuilt(image.label, function (res) {
          if (!res) return cb(new Error('Err while building docker image'))
          return built(cb)
        })
      } else return built(cb)

      function built (cb) {
        showProgress()
        // wait for docker container to be up
        var cidfile = 'temp/' + image.label + '.cid'
        waitContainer(cidfile, 10, function (res) {
          if (!res) return cb(new Error('Image Container cidfile ' + cidfile + ' not found. Timed out while waiting for container'))
          proc.exec('docker inspect ' + image.label + ' >temp/' + image.label + '.conf', function (err, stdout, stderr) {
            if (err) return cb(err)
            debugOut('get app container info')
            var imgconf
            var imgip
            var imgport
            try {
              imgconf = fs.readFileSync('temp/' + image.label + '.conf')
              imgconf = JSON.parse(imgconf)
              imgconf = imgconf[0]
              // determine ip
              imgip = imgconf.NetworkSettings.IPAddress
              // determine port
              imgport = imgconf.Config.ExposedPorts
              imgport = Object.keys(imgport)[0].toString().split('/')[0]
            } catch (err) {
              return cb(err)
            }
            debugOut('imgconf: ' + imgconf)
            debugOut('imgip: ' + imgip)
            debugOut('imgport: ' + imgport)
            builtImages[image.name] = true

            waitReady(imgip, imgport, image.label, function (res) {
              if (!res) return cb(new Error('Timed out while waiting for image'))
              debugOut('ready? ' + res)
              if (image.testTarget) {
                args.imagecontainer = {
                  label: image.label,
                  ip: imgip,
                  port: imgport
                }
              }
              return cb()
            })
          })
        })
      }
    }, delay)
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function runtest (args, cb) {
  console.log()
  if (flags.nt) {
    console.log('setup complete')
  } else {
    var testindex = 0
    console.log('run test')
    // pop a new terminal(gnome-terminal)
    var testlabel = 'test--' + testindex
    var base = 'temp/' + testlabel
    var infofile = base + '.json'
    // var logfile = base + '.log'
    var info = _.extend(args, {
      launchType: 'test',
      testlabel: testlabel,
      dbcontainer: args.dbcontainer,
      imagecontainer: args.imagecontainer,
      flags: flags,
      app: app
    })
    debugOut('run test & attach monitor')
    newWindow(infofile, info)
    cb()
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function monitor (args, cb) {
  console.log()
  if (flags.nm) {
    console.log('setup complete')
  } else {
    asyncRecurse(init, modifier, check, function () {
      debugOut('monitors-down')
      return cb()
    })
  }

  function init (cb) {
    console.log()
    console.log('monitor')
    debugOut('monitors up')
    return cb()
  }
  function modifier (cb) {
    return cb()
  }
  function check (cb) {
    process.stdout.write('.')

    var isErr = isEnd('err')
    debugOut('isErr: ' + isErr)
    var isFin = isEnd('fin')
    debugOut('isFin: ' + isFin)

    if (isErr || isFin) {
      if (isErr) failsSoFar++
      var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin
      process.stdout.write(msg)
      return cb(true) // needed to terminate recursion
    }

    return cb(false) // needed to continue recursion
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function grabFiles (args, cb) {
  console.log()
  console.log('moving logfiles')
  var logfolder = __dirname + '/log/'
  var folder = logfolder + args.db.label + '/'
  if (!fs.existsSync(folder)) fs.mkdirSync(folder)
  _.each(fs.readdirSync(logfolder), function (file) {
    if (file != 'dbt-manager') {
      var stats = fs.statSync(logfolder + file)
      if (stats.isFile()) {
        fs.renameSync(logfolder + file, folder + file)
      }
    }
  })
  return cb()
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function summarize () {
  console.log()
  console.log('results:\n')
  var logfolder = __dirname + '/log/'
  fs.mkdirSync(logfolder + '/fail/')
  fs.mkdirSync(logfolder + '/success/')

  var results = {}
  _.each(fs.readdirSync(logfolder), function (subfolder) {
    subfolder = subfolder + '/'

    if (!(subfolder === 'fail/' || subfolder === 'success/' || subfolder == 'dbt-manager/')) {
      var stats = fs.statSync(logfolder + subfolder)
      if (stats.isDirectory()) {
        // setup folder in results
        var label = subfolder.split('--')[0]
        if (!results[label]) results[label] = { success: 0, fail: 0 }
        var found = false

        // iterate files
        _.each(fs.readdirSync(logfolder + subfolder), function (file) {
          if (!found && file.split('.')[1] === 'err') found = true
        })

        // add up
        if (!found) results[label].success += 1
        else results[label].fail += 1

        var destinationFolder = found ? '/fail/' : '/success/'
        fs.renameSync(logfolder + subfolder, logfolder + destinationFolder + subfolder)
      }
    }
  })

  var longest = 0
  _.each(Object.keys(results), function (result) {
    if (result.length > longest) longest = result.length
  })

  // sum up
  var resultStr = ''
  _.each(Object.keys(results), function (result) {
    var success = results[result].success
    var fail = results[result].fail
    var total = success + fail
    var percentage = ((success / total) * 100).toFixed(2)
    while (result.length < longest) result = ' ' + result
    result += '\t' + 'SUCCESS RATE: ' + success + ' / ' + total + ' (' + percentage + '%)\n'
    resultStr += result
  })
  console.log(resultStr)
  resultStr = 'results:\n\n' + resultStr
  fs.writeFileSync(logfolder + 'readme.md', resultStr)
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function cleanup (cb) {
  console.log()
  console.log('cleanup')
  debugOut('PID: ' + process.pid)
  proc.exec('bash -e lib/kill-children.sh ' + process.pid, function (err, stdout, stderr) {
    debugOut('cln-err: ' + err)
    debugOut('cln-stdout: ' + stdout)
    debugOut('cln-stderr: ' + stderr)

    rimraf('temp/', function () {
      if (flags.cln) {
        if (!cleanedOnce) {
          console.log('sudo password required to erase docker bloat')
          cleanedOnce = true
        }
        proc.exec('bash -e lib/clean-docker.sh ' + process.pid, function (err, stdout, stderr) {
          debugOut('cln-err: ' + err)
          debugOut('cln-stdout: ' + stdout)
          debugOut('cln-stderr: ' + stderr)

          return cb()
        })
      } else return cb()
    })
  })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function isEnd (end) {
  var files = fs.readdirSync(__dirname + '/log/')
  debugOut('files: ' + util.inspect(files))
  var filebase
  var extension
  for (var i = 0; i < files.length; i++) {
    filebase = files[i].split('.')
    extension = filebase[1]
    filebase = filebase[0]
    if (extension === end) break
  }
  return (extension === end) ? filebase + '.' + extension : null
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function waitBuilt (img, cb) {
  asyncRecurse(init, modifier, check, cb)

  function init (cb) {
    console.log('wait for ' + img + ' image to be built:')
    return cb()
  }
  function modifier (cb) {
    return cb()
  }
  function check (cb) {
    lookForFile(__dirname + '/temp/' + img + '.fb', function (found) {
      if (found) return cb(true, true) // first true signals end of recursion, second is just data that is returned

      var isErr = isEnd('err')
      debugOut('isErr: ' + isErr)
      var isFin = isEnd('fin')
      debugOut('isFin: ' + isFin)

      if (isErr || isFin) {
        var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin
        process.stdout.write(msg)
        return cb(true, false)
      }

      return cb(false) // needed to continue recursion
    })
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function waitPulled (img, fd, cb) {
  console.log('wait for ' + img + ' image to be pulled:')

  var fbs = false
  var timeoutWaitingForFDS = 2000
  var timeWaitingForFDS = 0

  if (!fd) {
    var startFileCheckInterval = setInterval( function () {
      timeWaitingForFDS += 1000
      lookForFile(__dirname + '/temp/' + img + '.fds', function (found) {
        if (found) {
          fbs = true
          clearInterval(startFileCheckInterval)
          checkPulled(cb)
        }
      })
      if (timeWaitingForFDS >= timeoutWaitingForFDS) {
        clearInterval(startFileCheckInterval)
        if (!fbs) return cb(true) // if waiting docker pull start for more than 1 second and not forcing docker pull, assume pulled already
      }
    }, 1000)
  } else checkPulled(cb)

  function checkPulled(cb) {
    asyncRecurse(init, modifier, check, cb)

    function init (cb) {
      return cb()
    }
    function modifier (cb) {
      return cb()
    }
    function check (cb) {
      lookForFile(__dirname + '/temp/' + img + '.fde', function (found) {
        if (found) return cb(true, true) // first true signals end of recursion, second is just data that is returned

        var isErr = isEnd('err')
        debugOut('isErr: ' + isErr)
        var isFin = isEnd('fin')
        debugOut('isFin: ' + isFin)

        if (isErr || isFin) {
          var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin
          process.stdout.write(msg)
          return cb(true, false)
        }

        return cb(false) // needed to continue recursion
      })
    }
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function asyncRecurse (init, modifier, check, cb) {
  // async recursion!
  var func = function (cb) {
    // 1 sec delay
    setTimeout(function () {
      // condition modifier
      modifier(function () {
        // stop if condition met
        check(function (finished, res) {
          if (finished) return cb(res)

          // else call again
          func(cb)
        })
      })
    }, 1000)
  }

  // instructions before
  init(function () {
    // first call
    func(function (res) {
      console.log()
      return cb(res) // instructions after can be applied on callback
    })
  })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function waitContainer (cidfile, timeout, cb) {
  var calls = []
  for (var i = 0; i < timeout; i++) {
    calls.push(lookForFile.bind(null, cidfile))
    calls.push(function (next) {
      setTimeout(function () {
        next()
      }, 1000)
    })
  }

  console.log('wait for container:')
  async.series(calls, function (res) {
    console.log()
    cb(res)
  })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function lookForFile (file, cb) {
  fs.exists(file, function (res) {
    process.stdout.write('.')
    if (res) {
      fs.readFile(file, function (err, res) {
        if (err) process.stdout.write('') // supress lint
        if (res.length < 1) res = null
        cb(res)
      })
    } else cb(res)
  })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function waitReady (ip, port, label, cb) {
  asyncRecurse(init, modifier, check, cb)

  function init (cb) {
    console.log('wait for response at ' + ip + ':' + port)
    return cb()
  }
  function modifier (cb) {
    return cb()
  }
  function check (cb) {
    checkIfOnline(ip, port, function (online) {
      if (online) return cb(true, true) // first true signals end of recursion, second is just data that is returned

      var isErr = isEnd('err')
      debugOut('isErr: ' + isErr)
      var isFin = isEnd('fin')
      debugOut('isFin: ' + isFin)

      if (isErr || isFin) {
        var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin
        process.stdout.write(msg)
        return cb(true, false)
      }

      return cb(false) // needed to continue recursion
    })
  }

  function checkIfOnline (ip, port, cb) {
    debugOut("begin ping");
    proc.exec('curl -m 1 -v --url ' + ip + ':' + port + '/', function (err, stdout, stderr) {
      if (err) process.stdout.write('') // supress lint
      process.stdout.write('.')
      if (flags.debug) process.stdout.write(stdout)
      if (flags.debug) process.stdout.write(stderr)
      return cb(stderr.toString().indexOf('Accept') > -1)
    })
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function debugOut (msg) {
  if (flags.debug) console.log(msg)
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function newWindow (infofile, info) {
  fs.writeFileSync(infofile, JSON.stringify(info))
  if (flags.nw || flags.nwo) {
    spawn('node', ['lib/spawmon.js', infofile])
  } else {
    var cmd = 'gnome-terminal --disable-factory -x bash -c "echo GPID: $$; node lib/spawmon.js ' + infofile + '; read"'
    debugOut('cmd: ' + cmd)
    var term = proc.exec(cmd, function (err, stdout, stderr) {
      debugOut(term.pid + '-err: ' + err)
      debugOut(term.pid + '-stdout: ' + stdout)
      debugOut(term.pid + '-stderr: ' + stderr)
    })
  }
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function spawn (cmd, args) {
  console.log()
  console.log('running ' + cmd + ' ' + args)
  console.log()
  var cp = proc.spawn(cmd, args)
  cp.stdout.on('data', function (data) {
    process.stdout.write(data)
  })
  cp.stderr.on('data', function (data) {
    process.stdout.write(data)
  })
  cp.on('close', function (code) {
    console.log('child process exited with code ' + code)
  })
  return cp
}
