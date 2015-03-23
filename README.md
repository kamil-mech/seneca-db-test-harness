# seneca-db-test-harness
Runs and exposes seneca db stores as separate server

This is a personal repository. It is not part of the official seneca utilities.

Install:
```
    npm install seneca-db-test-harness
```

Currently supports:
- mem-store
- jsonfile-store

Usage:
- add code below to your app(before you add any plugins with seneca.use)
```
  var Harness = require('seneca-db-test-harness')
  var harness = new Harness()

  harness.host(db, function(server_config){
    setTimeout(function(){
      seneca
      .client(server_config)
      .ready(function(){

        seneca = this
        
        // do stuff, e.g.
        seneca.use('some-plugin')
        seneca.make$('something').save$()
        seneca.make$('something').list$()
      })
    }, 2000)
  })
```
- run your app
