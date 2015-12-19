"use strict";

// TODO: Look at
// http://stackoverflow.com/questions/25956566/node-js-redis-wait-for-connection

var proc = require('child_process');

var ip = "127.0.0.1";
var port = 6379;
asyncRecurse(init, modifier, check, function(){
  console.log('DONE')
});
function init(cb){
  console.log('wait for response at ' + ip + ':' + port);
  return cb();
}
function modifier(cb){
  return cb();
}
function check(cb){
  checkIfOnline(ip, port, function(online){
    return cb(false); // needed to continue recursion
  });
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function checkIfOnline(ip, port, cb){
  proc.exec('curl -m 1 -v --url ' + ip + ':' + port + '/', function(err, stdout, stderr){
    process.stdout.write('.');
    process.stdout.write(stdout);
    process.stdout.write(stderr);
    return cb(stderr.toString().indexOf('Accept') > -1);
  });
}

// ----------------------------------------------------------------------------------------------------------------------------------------
function asyncRecurse(init, modifier, check, cb){
  // async recursion!
  var func = function(cb){
    var self = this;
    // 1 sec delay
    setTimeout(function() {
      // condition modifier
      modifier(function(){
        // stop if condition met
        check(function(finished, res){
           if (finished) return cb(res);

          // else call again
          func(cb);
        });
      });
    }, 100);
  }

  // instructions before
  init(function(){
    // first call
    func(function(res){
      console.log();
      return cb(res); // instructions after can be applied on callback
    });
  });
}