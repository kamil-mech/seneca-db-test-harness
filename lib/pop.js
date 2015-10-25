"use strict";

var file   = process.argv[2];
var fs     = require('fs');
var util   = require('util');
var proc   = require('child_process');
var async  = require('async');

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
        next();
      });
    });
  }
  calls.push(function(next){
    var port = dbconst.port + ':' + dbconst.port; // exposure needed to allow for external pinging with nc
    docker.run({_:dbconst.image, name:info.db, p: port, cidfile: __dirname + '/../temp/' + info.dblabel + '.cid'}, null, function(status){
      next();
    });
  });

  async.series(calls, function(){
    // init complete
  });
} else if (info.launch === 'app') {
  setTerminalTitle(info.imagelabel);

  var calls = [];
  if (info.flags.fb) {
    calls.push(function(next){
      console.log('rebuilding image ' + info.image);
      docker.build({_:info.app.path + '/.', t:info.image}, null, function(status){
        next();
      });
    });
  }
  calls.push(function(next){
    console.log('dbconst: ' + util.inspect(dbconst));
    var link = dbconst.local ? null : info.db;
    var runobj = {_:info.image, name:info.imagelabel, e: 'db=' + info.db + '-store', cidfile: __dirname + '/../temp/' + info.imagelabel + '.cid'};
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

  if (info.dbcontainer) process.env[info.db + '_PORT_' + info.dbcontainer.port + '_TCP_ADDR'] = info.dbcontainer.ip;

  var cp = proc.spawn('bash', ['-c', 'cd ' + info.app.path + ' && npm test --db=' + info.db + '-store --ip=' + info.imgcontainer.ip + ' --port=' + info.imgcontainer.port]);
  // forward output
  cp.stdout.on('data', function (data) {
    process.stdout.write(data);
  })
  // error handler
  cp.stderr.on('data', function (data) {
    process.stdout.write(data);
  })
  // on close
  cp.on('close', function (code) {
  var msg = 'child process exited with code ' + code;
  });
}

function setTerminalTitle(title) {
  process.stdout.write(
    String.fromCharCode(27) + "]0;" + title + String.fromCharCode(7)
  );
}