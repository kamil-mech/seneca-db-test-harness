var seneca = require('seneca')();
var async = require('async')

var storeopts = {
  name: 'test',
  host: '172.17.0.2',
  port: 9160
};


var entname = 'typename'
var store = 'cassandra-store'
seneca.use(store, storeopts)

seneca.ready(function() {
  var entity = seneca.make$(entname)
  entity.someproperty = "something"
  entity.anotherproperty = 100

  function kTop (op, entity, next) {

    seneca.make$(entname)[op](entity, k)

    function k (err, res) {
      console.log(op + ' res: ' + res)
      return next()
    }
  }

  async.series([
    kTop.bind(null, 'save$', entity),
    kTop.bind(null, 'load$', {})
    ], function (err, res) {
      console.log('end')
    })
})