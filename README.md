# seneca-db-test-harness
Runs and exposes seneca db stores as separate process

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
seneca
.client({port:44040, pins:['role:entity, cmd:*',  'cmd:ensure_entity',  'cmd:define_sys_entity']})
.ready(function(){
  seneca = this
  
  // do stuff, e.g.
  seneca.use('some-plugin')
  seneca.make$('something').save$()
  seneca.make$('something').list$()
})
```
- run your app
