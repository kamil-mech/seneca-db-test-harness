# seneca-db-test-harness

Two main functionalities:
- Setup docker containers: run, link, feed (DBT Manager)
- Allow offline seneca stores to listen for seneca connections like regular DBs (Harness)

Install:
```
    npm install seneca-db-test-harness
```

Currently supports:
- mem-store (listen feature)
- jsonfile-store (listen feature)
- mongo-store
- redis-store
- postgresql-store
- mysql-store

DBT Manager usage:
- See this [README](../master/dbt/README.md)

Listen feature (Harness) usage:
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
