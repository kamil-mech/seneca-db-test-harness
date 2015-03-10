// This file is PUBLIC DOMAIN. You are free to cut-and-paste to start your own projects, of any kind
"use strict"

module.exports = function() {

  this.host = function(db, callback){
    var fs     = require('fs')
    var seneca = require('seneca')()

    // validate db choice
    var dbs_supported = ['mem-store', 'jsonfile-store']
    var err
    if (!db) err = 'no db specified' 
    if (dbs_supported.indexOf(db) === -1) err = 'unsupported db: ' + db
    if (err) return console.error('Error: ' + err + '. try --db=jsonfile-store or any other: ' + dbs_supported)

    // setup server config
    require('dns').lookup(require('os').hostname(), function (err, addr) {
      var host = addr
      var port = 44040

      console.log('\nusing ' + db + '\ndb address: '+ host + ':' + port + '\n')

      // ensure main db folder
      var db_path = __dirname + '/db/'
      if (!fs.existsSync(db_path)) fs.mkdirSync(db_path)
      // ensure chosen db subfolder
      if (!fs.existsSync(db_path + db)) fs.mkdirSync(db_path + db)
        
      // apply default pins
      var pins = ['role:entity, cmd:*',  'cmd:ensure_entity',  'cmd:define_sys_entity']

      // apply db-specific config
      var db_args
      if (db === 'mem-store') {
        db_args = {web:{dump:true}}
      }
      else if (db === 'jsonfile-store') {
        db_args = {folder:db_path}
      }

      var server_args = {host:host, port:port, pins:pins}
      // open db service
      seneca
      .use(db, db_args)
      .listen(server_args, function(){
        server_args.name = db
        callback(server_args)
      })
    })
  }
}