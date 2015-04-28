
"use strict"

module.exports = init

function init (handler) {

  var db = process.env['npm_config_db']
  var ip = process.env['npm_config_ip']
  var port = process.env['npm_config_port']

  var _  = require('lodash')
  var fs = require('fs')
  var util = require('util')

  var si = require('seneca')({
    errhandler: handler,
    default_plugins:{'mem-store':false}
  })
  // init and clean db
  if (!db){
    throw new Error('No db specified. try npm test --db=mem-store or any other store')
    process.exit(0)
  }
  console.log('using ' + db + ' db')

  var db_path = __dirname + '/temp/unit-db/'
  // ensure db folder
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)
  db_path += db
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)

  // get options
  si.use('options', './smoke.options.js')

  // setup db-specific args
  var db_args = {}
  if (db === 'jsonfile-store') db_args = {folder:db_path}
  
  if (ip && ip !== '' && port && port !== '') {
    db_args.host = ip
    db_args.port = port
  }
  if (db_args.host && db_args.port) console.log('connecting at ' + db_args.host + ':' + db_args.port)
    else console.log('db connection is internal')
  si.use(db, db_args)

  clean_db()

  // erase all entities from db
  function clean_db(){
    erase('sys/user', function() {
      if ('db' === 'jsonfile-store') si.make$('sys', 'entity').save$()
      return
    })
  }

  // erase particular entity from db
  function erase (entity, callback){
    si.act({role:'entity', cmd:'remove', qent:si.make(entity), q:{all$ : true}}, function(err, data){
      if (err) si.error(err)
        callback(err)
    })
  }

  return {
    si:si,
    alive: function(){ // TODO remove
      console.log('Ayam Heeah')
    }
  }
}