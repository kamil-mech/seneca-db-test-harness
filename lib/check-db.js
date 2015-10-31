"use strict";

var seneca = require('seneca')({default_plugins:{'mem-store':false}});
var util   = require('util');

var dbc = function(args){
  var success = true;
  if (!args.db || !args.host || !args.port) {
    console.log('WARNING! UNABLE TO REACH DB');
    success = false;
    return;
  }

  var dbargs = {
    name: 'test',
    host: args.host,
    port: args.post
  };
  seneca.use(args.db + '-store', dbargs);

  return {
    success: success,
    check: function (cb) {
      if (!success) return cb(new Error('DB config corrupted'));

      seneca.make$('test').save$({test1: 'test', test2: { test2a: true, test2b: 1 } }, function(err, res){
        // console.log('err1: ' + err);
        // console.log('res1: ' + res);
        if (err) return cb(err);
        seneca.make$('test').load$({test1: 'test'}, function(err, res){
        //   console.log('err2: ' + err);
        //   console.log('res2: ' + res);
          return cb(err, res);
        });
      });
    }
  };
}

module.exports = dbc;