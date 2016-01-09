"use strict";

var file   = process.argv[2];
var fs     = require('fs');
var util   = require('util');
var proc   = require('child_process');
var async  = require('async');
var _      = require('lodash');

var Docker = require('docker-cmd');
var docker = new Docker();

console.log('file: ' + file);

var info;

try {
  info = fs.readFileSync(file);
  info = JSON.parse(info);
} catch(err){
  throw err;
}

console.log('conf: ' + util.inspect(info));

var dbconst = info.dbconst;
if (info.launch === 'db') {
  setTerminalTitle(info.dblabel);

  var calls = [];
  if (info.flags.fd) {
    calls.push(function(next){
      console.log('pulling docker image for ' + dbconst.image + '...')
      proc.exec('docker pull ' + dbconst.image, function(err, stdout, stderr){
        if (err) console.log(err)
        if (stdout) console.log(stdout)
        if (stderr) console.log(stderr)
        fs.writeFileSync(__dirname + '/../temp/' + info.dblabel + '.fd', ' ');
        next();
      });
    });
  }

  // runscript or regular
  if (info.dbconst.run) {
    // runscript
    var cmdargs = [];
    _.each(info.dbconst.reads, function(option){
      cmdargs.push(info.dbOptions[option]);
    });
    cmdargs.push(__dirname + '/../temp/' + info.dblabel + '.cid'); // cidfile
    cmdargs.unshift(__dirname + '/../dbs' + info.dbconst.run);
    calls.push(function(next){
      console.log('cmdargs: ' + cmdargs)
      var cp = spawn('bash', cmdargs);
      next();
    });
  } else {
    // regular
    calls.push(function(next){
      var port = dbconst.port + ':' + dbconst.port; // exposure needed to allow for pinging
      docker.run({_:dbconst.image, name:info.db, p: port, cidfile: __dirname + '/../temp/' + info.dblabel + '.cid'}, null, function(status){
        next();
      });
    });
  }

  async.series(calls, function(){
    // init complete
  });
} else if (info.launch === 'app') {
  setTerminalTitle(info.imagelabel);

  var calls = [];
  if (info.flags.fb) {
    calls.push(function(next){
      console.log('rebuilding image ' + info.image.name);
      docker.build({_:info.image.path, t:info.image.name}, null, function(status){
        fs.writeFileSync(__dirname + '/../temp/' + info.imagelabel + '.fb', ' ');
        next();
      });
    });
  }
  
  if (info.dbcontainer) {
    var env = info.db.toUpperCase() + '_PORT_' + info.dbcontainer.port + '_TCP_ADDR';
    console.log('Export ' + env + '=' + info.dbcontainer.ip);
    process.env[env] = info.dbcontainer.ip;
  }

  calls.push(function(next){
    console.log('dbconst: ' + util.inspect(dbconst));
    var link = dbconst.local ? null : info.db;
    var runobj = {_:info.image.name, name:info.imagelabel, e: 'db=' + info.db + '-store', cidfile: __dirname + '/../temp/' + info.imagelabel + '.cid'};
    if (link) runobj.link = link;
    docker.run(runobj, null, function(status){
      next();
    });
  });

  async.series(calls, function(){
    // init complete
  });
} else if (info.launch === 'test') {
  setTerminalTitle(info.testlabel);

  if (info.dbcontainer) {
    var env = info.db.toUpperCase() + '_PORT_' + info.dbcontainer.port + '_TCP_ADDR';
    console.log('Export ' + env + '=' + info.dbcontainer.ip);
    process.env[env] = info.dbcontainer.ip;
  }

  var cp = spawn('bash', ['-c', 'cd ' + info.testpath + '; npm test --db=' + info.db + '-store --ip=' + info.imgcontainer.ip + ' --port=' + info.imgcontainer.port]);
}

function setTerminalTitle(title) {
  if (!info.flags.nw) {
    process.stdout.write(
      String.fromCharCode(27) + "]0;" + title + String.fromCharCode(7)
    );
  }
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