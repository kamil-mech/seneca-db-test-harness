"use strict";

// remember to error check everything for failure points. Also suggest solutions
var util   = require('util');
var _      = require('lodash');
var async  = require('async');
var fs     = require('fs');
var proc   = require('child_process');

var rimraf = require('rimraf');
var DBC    = require(__dirname + '/lib/check-db.js');
var dbc;

var cleanedOnce = false; // if cleaned at least once. Used for not spamming for sudo requests

process.on('SIGINT', function () {
  cleanup(function(){
    process.exit(0);
  });
});

process.on('uncaughtException', function (err) {
  cleanup(function(){
    console.log('Uncaught exception: ' + err.stack);
    process.exit(1);
  });
});


// enchancement: until-error or until-success
// TODO supports:
// -dbs
// -fd
// -fb
// -tu
// -ta
// -nt
// -man
// -cln <-- requires sudo
// -timg
// -debug

var gargs = process.argv;
gargs.shift();
gargs.shift();
var flags = {};
var extras = [];
var dbs = [];
var app = {};

var calls = [];
var current = 0;

// preload
console.log('---------');
console.log('init');
cleanup(function(){
  setTerminalTitle('DBT Manager');
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
        for (var i = 0; i < iterations; i++) {;
          calls.push(main.bind(null, {db: db, i: i}));
        };
      });
      // in series
      cleanup(function(){
        async.series(calls, function(){
          console.log('---------');
          console.log('final cleanup');
          summarize();
          console.log();
          process.kill(process.pid, 'SIGINT'); // TODO remove 
        });
      });
    });
  });
});

function main(args, cb){
    args = _.clone(args); // this makes sure args do not overlap between iterations
    var db = args.db;
    var i = args.i;
    current += 1;
    setTerminalTitle('DBT Manager (' + current + '/' + calls.length + ')');
    // main body
    console.log('---------');
    console.log('start ' + db + '-' + i);
    if (!fs.existsSync('temp/')) fs.mkdirSync('temp/');
    async.series([
        function(next){ rundb(args, next); },
        function(next){ runapp(args, next); },
        function(next){ runtest(args, next); },
        function(next){ monitor(args, next); },
        cleanup,
        function(next){ grabFiles(args, next); }
      ], function(err, res){
      if (err) {
        console.log(err.stack + '\nSkip to next');
        fs.writeFileSync(__dirname + '/log/dbt-manager.err', err.stack)
      }
      cleanup(function(){
        grabFiles(args, function(){
          console.log('end ' + db + '-' + i);
          return cb();
        });
      });
    })
}

// ----------------------------------------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------------------------------------

function processArgs(){
  console.log();
  console.log('process args');

  debugOut('gargs: ' + gargs);
  if (_.isEmpty(gargs)) throw new Error('no args provided');

  app.name = gargs[0];
  gargs.shift();
  debugOut('app: ' + app.name);

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
  app.path = __dirname + '/../' + app.name + '/';
  debugOut('app.path: ' + app.path);

  var files = fs.readdirSync(app.path);
  debugOut('files: ' + files);

  var optionsFile = _.find(files, function(file) {
    return file.indexOf('options') > -1;
  })
  debugOut('optionsFile: ' + optionsFile);

  var options = require(app.path + optionsFile);
  if (!options.dbt) throw new Error('no options provided');
  if (!options.dbt.dockimages) throw new Error('no dockimages provided');
  debugOut('options: ' + util.inspect(options.dbt));
  app.options = options;
}

// enchancement: send params to dbs
function rundb(args, cb){
  var db = args.db;
  var i = args.i;
  console.log();
  console.log('run db ' + args.db);
  debugOut('load db specific constants');
  try {
    var dbconst = fs.readFileSync('dbs/' + db + '.json');
    dbconst = JSON.parse(dbconst);
    args.dbconst = dbconst;
    debugOut('dbconst: ' + util.inspect(dbconst));
  } catch(err){
    if (err.message.indexOf('ENOENT') > -1) return cb(new Error('DB ' + db + ' is not supported'));
  }

  var dblabel = db + '--' + i;
  args.dblabel = dblabel;
  if (!dbconst.local) {

    // pop a new terminal(gnome-terminal)
    var base = 'temp/' + dblabel;
    var infofile = base + '.json';
    var logfile = base + '.log';
    var info =  args;
    info.dbconst = args.dbconst; // enchancement: gather all db info into one object
    info.launch = 'db';
    info.dblabel = dblabel;
    info.flags = flags;

    // ensure init options are in options file
    if (dbconst.init) {
      var opts = app.options[db + '-store'];
      if (opts) {
        _.each(dbconst.reads, function(field){
          if (!opts[field]) return cb(new Error(db + ' option ' + field + ' not found in options file'));
        })
        info.dbOptions = opts;
      } else return cb(new Error(db + ' options not found in options file'));
    };

    fs.writeFileSync(infofile, JSON.stringify(info));
    debugOut('run db image & attach monitor');
    var cmd = 'gnome-terminal --disable-factory -x bash -c "echo GPID: $$; node lib/spawmon.js ' + infofile + '; read"';
    debugOut('cmd: ' + cmd);
    var term = proc.exec(cmd, function(err, stdout, stderr){
      debugOut(term.pid + '-err: ' + err);
      debugOut(term.pid + '-stdout: ' + stdout);
      debugOut(term.pid + '-stderr: ' + stderr);
    });

    // wait for db
    if (flags.fd) {
      waitPulled(dblabel, function(res){
      if (!res) return cb(new Error('Err while pulling docker image'))
        return pulled(cb);
      });
    } else return pulled(cb);
  } else return cb();

  function pulled(cb){
    // wait for docker container to be up
    var cidfile = 'temp/' + dblabel + '.cid';
    waitContainer(cidfile, 10, function(res){
      if (!res) return cb(new Error('DB Container cidfile ' + cidfile + ' not found. Timed out while waiting for container'))
      proc.exec('docker inspect ' + db + ' >temp/' + dblabel + '.conf', function(err, stdout, stderr){
        debugOut('get db container info');
        var dbconf;
        try {
          dbconf = fs.readFileSync('temp/' + dblabel + '.conf');
          dbconf = JSON.parse(dbconf);
          dbconf = dbconf[0];
        } catch(err) {
          return cb(err);
        }
        debugOut('dbconf: ' + util.inspect(dbconf));
        var dbip = dbconf.NetworkSettings.IPAddress;
        if (info.dbOptions) info.dbOptions.dbip = dbip;
        debugOut('dbconfIP: ' + dbip)

        flags.fd = false; // echancement: register which are pulled and which are not
        waitReady(dbip, dbconst.port, dblabel, function(res){
        if (!res) return cb(new Error('Timed out while waiting for db'))

          setTimeout(function() {
            args.dbcontainer = {
              dblabel: dblabel,
              ip: dbip,
              port: dbconst.port
            }
            // run init script or proceed to sanity check
            if (dbconst.init) { // TODO sanity check here too(resolve mysql schema preload for test entities)
                console.log('init ' + db);
                var cmdargs = [];
                _.each(dbconst.reads, function(option){
                  cmdargs.push(info.dbOptions[option]);
                });
                _.each(dbconst.computes, function(option){
                  cmdargs.push(info.dbOptions[option]);
                });
                cmdargs.unshift(__dirname + '/dbs/' + dbconst.init);
                var cp = spawn('bash', cmdargs);
                cp.on('close', function (code) {
                  return cb();
                });
            } else {
              // sanity check
              var target = {
                db: db,
                host: dbip,
                port: dbconst.port,
              }
              dbc = DBC(target);
              dbc.check(function(err, res){
                  return cb(err, res);
              });
            }
          }, 1000);
        });
      });
    });
  }
}

function runapp(args, cb){
  var db = args.db;
  var i = args.i;
  console.log();
  console.log('run app');

  var image = app.options.dbt.dockimages;
  var image = image[0]; // TODO REPLACE WITH ITERATION
  image = image.split(' ');
  image = image[image.length - 1];
  var imagelabel = image + '--' + i;
  debugOut('imagelabel: ' + imagelabel);

  // pop a new terminal(gnome-terminal)
  var base = 'temp/' + imagelabel;
  var infofile = base + '.json';
  var logfile = base + '.log';
  var info =  args;
  info.launch = 'app';
  info.app = app;
  info.image = image;
  info.imagelabel = imagelabel;
  info.flags = flags;
  info.dbconst = args.dbconst;
  fs.writeFileSync(infofile, JSON.stringify(info));
  debugOut('run app image ' + imagelabel + ' & attach monitor');
  var cmd = 'gnome-terminal --disable-factory -x bash -c "echo GPID: $$; node lib/spawmon.js ' + infofile + '; read"';
  debugOut('cmd: ' + cmd);
  var term = proc.exec(cmd, function(err, stdout, stderr){
    debugOut(term.pid + '-err: ' + err);
    debugOut(term.pid + '-stdout: ' + stdout);
    debugOut(term.pid + '-stderr: ' + stderr);
  });
  // wait for image
  debugOut('wait for app container');

  if (flags.fb) {
    waitBuilt(imagelabel, function(res){
    if (!res) return cb(new Error('Err while building docker image'))
      return built(cb);
    });
  } else return built(cb);

  function built(cb){
    // wait for docker container to be up
    var cidfile = 'temp/' + imagelabel + '.cid';
    waitContainer(cidfile, 10, function(res){
      if (!res) return cb(new Error('Image Container cidfile ' + cidfile + ' not found. Timed out while waiting for container'))
      proc.exec('docker inspect ' + imagelabel + ' >temp/' + imagelabel + '.conf', function(err, stdout, stderr){
        debugOut('get app container info');
        var imgconf;
        var imgip;
        var imgport;
        try {
          imgconf = fs.readFileSync('temp/' + imagelabel + '.conf');
          imgconf = JSON.parse(imgconf);
          imgconf = imgconf[0];
          // determine ip
          imgip = imgconf.NetworkSettings.IPAddress;
          // determine port
          imgport = imgconf.Config.ExposedPorts;
          imgport = Object.keys(imgport)[0].toString().split('/')[0];
        } catch(err) {
          return cb(err);
        }
        debugOut('imgconf: ' + imgconf);
        debugOut('imgip: ' + imgip);
        debugOut('imgport: ' + imgport); // enchancement: look for more ports to try or get specifics from the conf
        flags.fb = false;

        waitReady(imgip, imgport, imagelabel, function(res){
        if (!res) return cb(new Error('Timed out while waiting for image'))
          debugOut('ready? ' + res);
          args.imgcontainer = { // enchancement: multiple images
            imagelabel: imagelabel,
            ip: imgip,
            port: imgport
          }
          return cb();
        });
      });
    });
  }
}

function runtest(args, cb){
  console.log();
  if (flags.nt) {
    console.log('setup complete');
  } else {
    console.log('run test');
    // pop a new terminal(gnome-terminal)
    var testlabel = 'test--' + args.i;
    var base = 'temp/' + testlabel;
    var infofile = base + '.json';
    var logfile = base + '.log';
    var info =  args;
    info.launch = 'test';
    info.testlabel = testlabel;
    info.dbcontainer = args.dbcontainer;
    info.imgcontainer = args.imgcontainer;
    info.flags = flags;
    info.app = app;
    fs.writeFileSync(infofile, JSON.stringify(info));
    debugOut('run test & attach monitor');
    var cmd = 'gnome-terminal --disable-factory -x bash -c "echo GPID: $$; node lib/spawmon.js ' + infofile + '; read"';
    debugOut('cmd: ' + cmd);
    var term = proc.exec(cmd, function(err, stdout, stderr){
      debugOut(term.pid + '-err: ' + err);
      debugOut(term.pid + '-stdout: ' + stdout);
      debugOut(term.pid + '-stderr: ' + stderr);
    });
    cb();
  }
}

function monitor(args, cb){
  console.log();
  console.log('monitor');
  debugOut('monitors up');

  var calls = [];
  // async recursion!
  var func = function(cb){
    var self = this;
    // 1 sec delay
    setTimeout(function() {
      process.stdout.write('.');
      // condition modifier
      // - none

      // stop if condition met
      var isErr = isEnd('err');
      debugOut('isErr: ' + isErr);
      var isFin = isEnd('fin');
      debugOut('isFin: ' + isFin);

      if (isErr || isFin) {
        // enchancement: list of ignored errors
        var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin;
        process.stdout.write(msg);
        return cb(null);
      }

      // else call again
      func(cb);
    }, 1000);
  }
  calls.push(func);
  async.series(calls, function(){
    console.log();
    debugOut('monitors-down');
    return cb();
  });
}

function grabFiles(args, cb){
  console.log();
  console.log('moving logfiles');
  var logfolder = __dirname + '/log/';
  var folder = logfolder + args.dblabel + '/';
  if (!fs.existsSync(folder)) fs.mkdirSync(folder);
  _.each(fs.readdirSync(logfolder), function(file){
    var stats = fs.statSync(logfolder + file);
    if (stats.isFile()) {
      fs.renameSync(logfolder + file, folder + file);
    }
  });
  return cb();
}

function summarize(){
  console.log();
  console.log('results:\n');
  var logfolder = __dirname + '/log/';
  fs.mkdirSync(logfolder + '/fail/');
  fs.mkdirSync(logfolder + '/success/');

  var results = {};
  _.each(fs.readdirSync(logfolder), function(subfolder){
      subfolder = subfolder + '/';

      if (!(subfolder === 'fail/' || subfolder == 'success/')) {
        var stats = fs.statSync(logfolder + subfolder);
        if (stats.isDirectory()) {

          // setup folder in results
          var label = subfolder.split('--')[0];
          if (!results[label]) results[label] = { success: 0, fail: 0 };
          var found = false;

          // iterate files
          _.each(fs.readdirSync(logfolder + subfolder), function(file){
            if (!found && file.split('.')[1] === 'err') found = true;
          });

          // add up
          if (!found) results[label].success += 1;
          else results[label].fail += 1;

          var destinationFolder = found ? '/fail/' : '/success/';
          fs.renameSync(logfolder + subfolder, logfolder + destinationFolder + subfolder);
        }
      }
  });

  var longest = 0;
  _.each(Object.keys(results), function(result){
    if (result.length > longest) longest = result.length;
  });

  // sum up
  var resultStr = '';
  _.each(Object.keys(results), function(result){
    var success = results[result].success;
    var fail = results[result].fail;
    var total = success + fail;
    var percentage = ((success / total) * 100).toFixed(2);
    while (result.length < longest) result = ' ' + result;
    result += '\t' + 'SUCCESS RATE: ' + success + ' / ' + total + ' (' + percentage + '%)\n';
    resultStr += result;
  });
  console.log(resultStr);
  resultStr = 'results:\n\n' + resultStr;
  fs.writeFileSync(logfolder + 'readme.md', resultStr);
}

// enchancement: cleanup after last run of the program
function cleanup(cb){
  console.log();
  console.log('cleanup')
  debugOut('PID: ' + process.pid);
  proc.exec('bash -e lib/kill-children.sh ' + process.pid, function(err, stdout, stderr){
    debugOut('cln-err: ' + err);
    debugOut('cln-stdout: ' + stdout);
    debugOut('cln-stderr: ' + stderr);

    rimraf('temp/', function(){
      if (flags.cln) {
        if (!cleanedOnce) {
          console.log('sudo password required to erase docker bloat');
          cleanedOnce = true;
        }
        proc.exec('bash -e lib/clean-docker.sh ' + process.pid, function(err, stdout, stderr){
          debugOut('cln-err: ' + err);
          debugOut('cln-stdout: ' + stdout);
          debugOut('cln-stderr: ' + stderr);

          return cb();
        });
      } else return cb();
    });
  });
}

function isEnd(end){
  var files = fs.readdirSync(__dirname + '/log/');
  debugOut('files: ' + util.inspect(files));
  var filebase;
  var extension;
  for (var i = 0; i < files.length; i++) {
    filebase = files[i].split('.');
    extension = filebase[1];
    filebase = filebase[0];
    if (extension === end) break;
  };
  return (extension === end) ? filebase + '.' + extension : null;  
}

function waitBuilt(img, cb){
    var calls = [];
    // async recursion!
    var func = function(cb){
      var self = this;
      // 1 sec delay
      setTimeout(function() {
        // condition modifier
        // - none

        // stop if condition met
        lookForFile(__dirname + '/temp/' + img + '.fb', function(found){

          if (found) return cb(true);

          var isErr = isEnd('err');
          debugOut('isErr: ' + isErr);
          var isFin = isEnd('fin');
          debugOut('isFin: ' + isFin);

          if (isErr || isFin) {
            var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin;
            process.stdout.write(msg);
            return cb(false);
          }

          // else call again
          func(cb);
        });
      }, 1000);
    }
    calls.push(func);
    console.log('wait for ' + img + ' image to be built:');
    async.series(calls, function(res){
      console.log();
      return cb(res);
    });
}

// enchancement abstract the async recursion as majority repeats alot
function waitPulled(img, cb){
    var calls = [];
    // async recursion!
    var func = function(cb){
      var self = this;
      // 1 sec delay
      setTimeout(function() {
        // condition modifier
        // - none

        // stop if condition met
        lookForFile(__dirname + '/temp/' + img + '.fd', function(found){

          if (found) return cb(true);

          var isErr = isEnd('err');
          debugOut('isErr: ' + isErr);
          var isFin = isEnd('fin');
          debugOut('isFin: ' + isFin);

          if (isErr || isFin) {
            var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin;
            process.stdout.write(msg);
            return cb(false);
          }

          // else call again
          func(cb);
        });
      }, 1000);
    }
    calls.push(func);
    console.log('wait for ' + img + ' image to be pulled:');
    async.series(calls, function(res){
      console.log();
      return cb(res);
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
}

function lookForFile(file, cb){
  fs.exists(file, function(res){
    process.stdout.write('.');
    if (res){
      fs.readFile(file, function(err, res){
        if (res.length < 1) res = null;
        cb(res);
      });
    } else cb(res);
  });
}

function waitReady(ip, port, label, cb){

  var calls = [];
  // async recursion!
  var func = function(cb){
    var self = this;
    // 1 sec delay
    setTimeout(function() {
      // condition modifier
      // - none

      // stop if condition met
      checkIfOnline(ip, port, function(online){

        if (online) return cb(true);

        var isErr = isEnd('err');
        debugOut('isErr: ' + isErr);
        var isFin = isEnd('fin');
        debugOut('isFin: ' + isFin);

        if (isErr || isFin) {
          var msg = (isErr) ? ' Error detected at ' + isErr : ' Fin detected at ' + isFin;
          process.stdout.write(msg);
          return cb(false);
        }

        // else call again
        func(cb);
      });
    }, 1000);
  }
  calls.push(func);
  console.log('wait for response at ' + ip + ':' + port);
  async.series(calls, function(res){
    console.log();
    return cb(res);
  });

  function checkIfOnline(ip, port, cb){
    proc.exec('curl -m 1 -v --url ' + ip + ':' + port + '/', function(err, stdout, stderr){
      process.stdout.write('.');
      if (flags.debug) process.stdout.write(stdout);
      if (flags.debug) process.stdout.write(stderr);
      return cb(stderr.toString().indexOf('Accept') > -1);
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

function spawn(cmd, args){
  console.log();
  console.log('running ' + cmd + ' ' + args)
  console.log();
  var cp = proc.spawn(cmd, args);
  cp.stdout.on('data', function (data) {
    process.stdout.write(data);
  });
  cp.stderr.on('data', function (data) {
    process.stdout.write(data);
  });
  cp.on('close', function (code) {
    console.log('child process exited with code ' + code);
  });
  return cp;
}