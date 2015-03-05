// This file is PUBLIC DOMAIN. You are free to cut-and-paste to start your own projects, of any kind
"use strict"

var fs     = require('fs')
var argv   = require('optimist').argv
var db     = argv.db
var seneca = require('seneca')()

var dbs_supported = ['jsonfile-store']
if (!db) return console.error('Error: no db specified. try --db=jsonfile-store or any other: ' + dbs_supported)
if (dbs_supported.indexOf(db) === -1) return console.error('Error: unsupported db. try one of those: ' + dbs_supported)

// setup server info
require('dns').lookup(require('os').hostname(), function (err, addr) {
  var host = addr
  var port = 44040

  // setup meta info
  var metapath
  if (addr === '127.0.1.1') metapath = __dirname + '/meta/'
    else metapath = 'meta/'
  var metafile = metapath + 'db.meta.json'

  // ensure meta folder
  if (!fs.existsSync(metapath)) fs.mkdirSync(metapath)

  // write server address to output file
  var info = {
    ip:host,
    port:port
  }
  fs.writeFile(metafile, JSON.stringify(info), function(err) {
    if(err) throw err
    console.log('\ndb address: '+ host + ':' + port + '\n')
  })

  // init db config
  var db_path = __dirname + '/db'
  var db_args = {}
  var pins = []
  // ensure db folder
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)

  // apply db-specific config
  if (db === 'jsonfile-store')
  {
    db_path = db_path + '/jsonfile'
    db_args = {folder:db_path}
    pins = ['role:entity, cmd:*',  'cmd:ensure_entity',  'cmd:define_sys_entity']
  }

  // ensure chosen db subfolder
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)

  // open db service
  seneca
  .use(db, db_args)
  .listen({host:host, port:port, pins:pins})
})