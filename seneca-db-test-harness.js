// This file is PUBLIC DOMAIN. You are free to cut-and-paste to start your own projects, of any kind
"use strict"

var fs     = require('fs')
var argv   = require('optimist').argv
var db     = argv.db ? argv.db : process.env.db
var seneca = require('seneca')()

// validate db choice
var dbs_supported = ['mem-store', 'jsonfile-store']
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

  // write meta info into the output file
  var info = {
    ip:host,
    port:port
  }
  fs.writeFile(metafile, JSON.stringify(info), function(err) {
    if(err) throw err
      console.log('\nusing ' + db)
      console.log('db address: '+ host + ':' + port + '\n')
  })

  // ensure db folder
  var db_path = __dirname + '/db'
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)
    
  // apply default pins
  var pins = ['role:entity, cmd:*',  'cmd:ensure_entity',  'cmd:define_sys_entity']

  // apply db-specific config
  var db_args = {}
  if (db === 'mem-store') {
    db_args = {web:{dump:true}}
  }
  else if (db === 'jsonfile-store') {
    db_args = {folder:db_path}
  }

  // ensure chosen db subfolder
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path +  '/' + db)

  // open db service
  seneca
  .use(db, db_args)
  .listen({host:host, port:port, pins:pins})
})