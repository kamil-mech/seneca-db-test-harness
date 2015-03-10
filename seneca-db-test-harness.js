// This file is PUBLIC DOMAIN. You are free to cut-and-paste to start your own projects, of any kind
"use strict"

var fs     = require('fs')
var argv   = require('optimist').argv
var db     = argv.db ? argv.db : process.env.db
var seneca = require('seneca')()
// var child  = require('child_process')

// validate db choice
// var dbs_supported = ['mem-store', 'mongo-store', 'jsonfile-store']
var dbs_supported = ['mem-store', 'jsonfile-store']
if (!db) return console.error('Error: no db specified. try --db=jsonfile-store or any other: ' + dbs_supported)
if (dbs_supported.indexOf(db) === -1) return console.error('Error: unsupported db ' + db + '. try one of those: ' + dbs_supported)

// setup server config
require('dns').lookup(require('os').hostname(), function (err, addr) {
  var host = addr
  var port = 44040

  // setup meta server_config
  var metapath
  if (addr === '127.0.1.1') metapath = __dirname + '/meta/'
    else metapath = 'meta/'
  var metafile = metapath + 'db.meta.json'

  // ensure meta folder
  if (!fs.existsSync(metapath)) fs.mkdirSync(metapath)

  // write meta server_config into the output file
  var server_config = {
    host:host,
    port:port
  }
  fs.writeFile(metafile, JSON.stringify(server_config), function(err) {
    if(err) throw err
      console.log('\nusing ' + db)
      console.log('db address: '+ host + ':' + port + '\n')
  })

  // ensure db folder
  var db_path = __dirname + '/db/'
  if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)
  // ensure chosen db subfolder
  if (!fs.existsSync(db_path + db)) fs.mkdirSync(db_path + db)
    
  // apply default pins
  var pins = ['role:entity, cmd:*',  'cmd:ensure_entity',  'cmd:define_sys_entity']
  server_config.pins = pins

  // apply db-specific config
  var db_args
  if (db === 'mem-store') {
    db_args = {web:{dump:true}}
    ready(server_config, db_args)
  }
  else if (db === 'jsonfile-store') {
    db_args = {folder:db_path}
    ready(server_config, db_args)
  }
  // else if (db === 'mongo-store'){
  //   child.spawn('mongod', ['--dbpath', db_path + db]).stdout.on('data', function (data) {
  //     console.log('stdout: ' + data)
  //     if (data.toString().indexOf('waiting') > -1){

  //       db_args = {
  //         name:'db-test',
  //         host:host,
  //         port:27017
  //       }

  //       ready(server_config, db_args)
  //     }
  //   })
  // }

})

function ready(server_config, db_args){
  // open db service
  seneca
  .use(db, db_args)
  .listen(server_config)
}