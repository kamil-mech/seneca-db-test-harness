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
setTerminalTitle(info.dblabel);
if (info.launch === 'db') {

    var calls = [];
    if (info.flags.fd) {
      calls.push(function(next){
        console.log('pulling docker image for ' + dbconst.image + '...')
        proc.exec('docker pull ' + dbconst.image, function(err, stdout, stderr){
          if (err) console.log(err)
          if (stdout) console.log(stdout)
          if (stderr) console.log(stderr)
          next();
        })
      })
    }
    calls.push(function(next){
      var port = dbconst.port + ':' + dbconst.port; // exposure needed to allow for external pinging with nc
      docker.run({_:dbconst.image, name:info.dblabel, p: port, cidfile: __dirname + '/../temp/' + info.dblabel + '.cid'}, null, function(status){
        next();
      })
    })

    async.series(calls, function(){
      // init complete
    })
} else if (info.launch === 'app') {
}

function setTerminalTitle(title) {
  process.stdout.write(
    String.fromCharCode(27) + "]0;" + title + String.fromCharCode(7)
  );
}