'use strict'

var seneca = require('seneca')({default_plugins: {'mem-store': false}})
var _ = require('lodash')

var dbc = function (args) {
  var success = true
  if (!args.db || !args.host || !args.port) {
    console.log('WARNING! UNABLE TO REACH DB')
    success = false
    return
  }

  var dbargs = {
    name: 'test',
    host: args.host,
    port: args.port
  }
  if (args.testargs) dbargs = _.extend(args.testargs, dbargs)
  seneca.use(args.db + '-store', dbargs)

  return {
    success: success,
    check: function (cb) {
      if (!success) return cb(new Error('DB config corrupted'))

      seneca.make$('test').save$({test1: 'test', test2: {test2a: true, test2b: 1}}, function (err, res) {
        if (err) return cb(err)
        seneca.make$('test').load$({test1: 'test'}, function (err, res) {
          return cb(err, res)
        })
      })
    }
  }
}

module.exports = dbc
