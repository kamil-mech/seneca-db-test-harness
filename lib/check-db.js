"use strict";

var seneca = require('seneca')({default_plugins:{'mem-store':false}});
var util   = require('util');

var dbc = function(args){
  if (!args.db || !args.host || !args.port) throw new Error('invalid args');

  var dbargs = {
    name: 'test',
    host: args.host,
    port: args.post
  };
  seneca.use(args.db + '-store', dbargs);

  return {
    check: function (cb) {
      seneca.make$('test').save$({test1: 'test', test2: { test2a: true, test2b: 1 } }, function(err, res){
        console.log('err1: ' + err);
        console.log('res1: ' + res);
        seneca.make$('test').load$({test1: 'test', test2: { test2a: true, test2b: 1 } }, function(err, res){
          console.log('err2: ' + err);
          console.log('res2: ' + res);
          cb(err, res);
        });
      });
    }
  };
}

module.exports = dbc;