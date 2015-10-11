"use strict";

// remember to error check everything for failure points. Also suggest solutions
var util   = require('util');
var _      = require('lodash');
var async  = require('async');
var fs     = require('fs');
var proc   = require('child_process');

var rimraf = require('rimraf');

process.on('SIGINT', function () {
  cleanup(function(){
    process.exit(0);
  })
});

// supports:
// -dbs
// -fd
// -fb
// -tu
// -ta
// -nt
// -st
// -man
// -aer
// -ner
// -timg
// -debug

var gargs = process.argv;
gargs.shift();
gargs.shift();
var flags = {};
var extras = [];
var dbs = [];
var appname;
var apppath;

// preload
console.log('---------');
console.log('init');
cleanup(function(){
  setTerminalTitle('DBT Manager')
  rimraf('temp/', function() {
    rimraf('log/', function() {
      fs.mkdirSync('log/');

      processArgs();
      loadConf();
      // iterations
      _.each(dbs, function(db){
        var iterations = 1;
        var more = db.split('-')[1]; // enchacement: more = last based on split array length
        if (more) iterations = parseInt(more);
        if (iterations.toString() === 'NaN') throw new Error('invalid multipicity syntax at ' + db)
        db = db.split('-')[0];
        debugOut('db: ' + db + '. iterations: ' + iterations)

        // call each db test multiplicity times
        var calls = [];
        for (var i = 0; i < iterations; i++) {
          calls.push(main.bind(null, {db: db, i: i}));
        };
        // in series
        async.series(calls, function(){
          console.log('---------');
          console.log('final cleanup');
          summarize();
          console.log();
        })
      });
    });
  });
});

function main(args, cb){
    var db = args.db;
    var i = args.i;
    // main body
    console.log('---------');
    console.log('start ' + db + '-' + i);
    if (!fs.existsSync('temp/')) fs.mkdirSync('temp/');
    async.series([
        function(next){ rundb(args, next); },
        function(next){ runapp(args, next); },
        function(next){ runtest(args, next); },
        function(next){ monitor(args, next); },
        cleanup
      ], function(err, res){
      if (err) console.log(err + '\nSkip to next');
      cleanup(function(){
        console.log('end ' + db + '-' + i);
        cb();
      });
    })
}


function processArgs(){
  console.log();
  console.log('process args');

  debugOut('gargs: ' + gargs);
  if (_.isEmpty(gargs)) throw new Error('no args provided');

  appname = gargs[0];
  gargs.shift();
  debugOut('app: ' + appname);

  var popdbs = false;
  _.each(gargs, function(arg){
    if (arg.charAt(0) === ('-')) {
      if (arg === '-dbs') popdbs = true;
      else popdbs = false;
      
      arg = arg.substring(1);
      flags[arg] = true;
    }
    else {
      if (popdbs) dbs.push(arg);
      else extras.push(arg);
    }
  });
  debugOut('flags: ' + util.inspect(flags));
  debugOut('extras: ' + extras);
  debugOut('dbs: ' + dbs);
}

function loadConf(){
  console.log();
  console.log('get conf from file');
  var apppath = __dirname + '/../' + appname + '/';
  debugOut('apppath: ' + apppath);

  var files = fs.readdirSync(apppath);
  debugOut('files: ' + files);

  var optionsFile = _.find(files, function(file) {
    return file.indexOf('options') > -1;
  })
  debugOut('optionsFile: ' + optionsFile);

  var options = require(apppath + optionsFile);
  if (!options.dbt) throw new Error('no options provided');
  if (!options.dbt.dockimages) throw new Error('no dockimages provided');
  debugOut('options: ' + util.inspect(options.dbt));
}

function rundb(args, cb){
  var db = args.db;
  var i = args.i;
  console.log();
  console.log('run db ' + args.db);
  debugOut('load db specific constants');
  try {
    var dbconst = fs.readFileSync('dbs/' + db + '.json');
    dbconst = JSON.parse(dbconst);
    debugOut('dbconst: ' + util.inspect(dbconst));
  } catch(err){
    if (err.message.indexOf('ENOENT') > -1) return cb(new Error('DB ' + db + ' is not supported'));
  }

  var dblabel = db + i;
  if (!dbconst.local) {

    // pop a new terminal(gnome-terminal)
    var base = 'temp/' + dblabel;
    var infofile = base + '.json';
    var logfile = base + '.log';
    var info =  args;
    info.dbconst = dbconst;
    info.launch = 'db';
    info.dblabel = dblabel;
    info.flags = flags;
    fs.writeFileSync(infofile, JSON.stringify(info));
    debugOut('run db image & attach monitor');
    var cmd = 'gnome-terminal --disable-factory -x bash -c "node lib/spawmon.js ' + infofile + '; read"';
    debugOut('cmd: ' + cmd);
    var term = proc.exec(cmd, function(err, stdout, stderr){
      debugOut(term.pid + '-err: ' + err);
      debugOut(term.pid + '-stdout: ' + stdout);
      debugOut(term.pid + '-stderr: ' + stderr);
    });
    var cidfile = 'temp/' + dblabel + '.cid';
    waitContainer(cidfile, 30, function(res){
      if (!res) return cb(new Error('DB Container cidfile ' + cidfile + ' not found. Timed out while waiting for container'))
      proc.exec('docker inspect ' + dblabel + ' >temp/' + dblabel + '.conf', function(err, stdout, stderr){
        debugOut('get db container info');
        var dbconf;
        try {
          dbconf = fs.readFileSync('temp/' + dblabel + '.conf');
          dbconf = JSON.parse(dbconf);
          dbconf = dbconf[0];
        } catch(err) {
          return cb(err);
        }
        debugOut('dbconf: ' + dbconf);
        var dbip = dbconf.NetworkSettings.IPAddress;
        debugOut('dbconfIP: ' + dbip)

        waitReady(dbip, dbconst.port, 60, function(res){
        if (!res) return cb(new Error('Timed out while waiting for db'))
          debugOut('ready? ' + res);
          return cb();
        });
      });
    })
  } else return cb();
}

function runapp(args, cb){
  console.log();
  console.log('run app');
  debugOut('build app image');
  debugOut('use db info');
  debugOut('run app image & attach monitor');
  debugOut('wait for app container');
  debugOut('get app container info');
  cb();
}

function runtest(args, cb){
  console.log();
  console.log('run test');
  debugOut('use db info');
  debugOut('use app info');
  debugOut('attach monitor to test');
  debugOut('run test');
  cb();
}

function monitor(args, cb){
  console.log();
  console.log('monitor');
  debugOut('monitors up');
  debugOut('scan...');
  setTimeout(function() {
    debugOut('monitors-down');
    cb();
  }, 3000);
}

function summarize(){
  console.log();
  console.log('print results');
}

function cleanup(cb){
  console.log();
  console.log('cleanup')
  debugOut('PID: ' + process.pid);
  proc.exec('bash -e lib/kill-children.sh ' + process.pid, function(err, stdout, stderr){
    debugOut('cln-err: ' + err);
    debugOut('cln-stdout: ' + stdout);
    debugOut('cln-stderr: ' + stderr);

    rimraf('temp/', cb);
  });
}

function waitContainer(cidfile, timeout, cb){
    var calls = [];
    for (var i = 0; i < timeout; i++) {
      calls.push(lookForFile.bind(null, cidfile));
      calls.push(function(next){ 
        setTimeout(function() {
          next();
        }, 1000);
      })
    };

    console.log('wait for container:');
    async.series(calls, function(res){
      console.log();
      cb(res);
    });

    function lookForFile(file, cb){
      fs.exists(file, function(res){
        if (res){
          fs.readFile(file, function(err, res){
            process.stdout.write('.');
            if (res.length < 1) res = null;
            cb(res);
          });
        } else cb(res);
      });
    }
}

// enchancement: do not use timeout, use detection of .err and .fin instead
function waitReady(ip, port, timeout, cb){
    var calls = [];
    for (var i = 0; i < timeout; i++) {
      calls.push(checkIfReady.bind(null, ip, port));
      calls.push(function(next){ 
        setTimeout(function() {
          next();
        }, 1000);
      })
    };

    console.log('wait for response:');
    async.series(calls, function(res){
      console.log();
      cb(res);
    })

  function checkIfReady(ip, port, cb){
    proc.exec('nc -v -z -w 1 ' + ip + ' ' + port, function(err, stdout, stderr){
      process.stdout.write('.');
      cb(stderr.toString().indexOf('succeed') > -1);
    });
  }
}

function debugOut(msg){
  if (flags.debug) console.log(msg);
}

function setTerminalTitle(title) {
  process.stdout.write(
    String.fromCharCode(27) + "]0;" + title + String.fromCharCode(7)
  );
}