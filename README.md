# seneca-db-test-harness 0.3.1

```
npm test --args="[PROJECT_NAME] [FLAGS]"
```

You will need:
- Config file in .js format(because it's compatible with seneca-stores). See below.
- Make sure your app is compatible with DBs used.
- (Optional) Set test, utest and atest scripts in app's package.json (and possibly posttest if you like). utest is unit-test and atest is acceptance-test. They let you use -tu and -ta flags.

Example of config file using one app image and two DBs:
```
module.exports = {

  // options for seneca-redis-store
  'redis-store':{
    host:process.env.REDIS_LINK_PORT_6379_TCP_ADDR || 'localhost',
    port:process.env.REDIS_LINK_PORT_6379_TCP_PORT || 6379
  },

  // options for seneca-mysql-store
  'mysql-store':{
    host:process.env.MYSQL_LINK_PORT_3306_TCP_ADDR || 'localhost',
    port:process.env.MYSQL_LINK_PORT_3306_TCP_PORT || 3306,
    user:'root', // to keep things simple this has to be root
    password:'password',
    name:'admin',
    schema:'/test/dbs/mysql.sql'
  },

  // options for db test
  'dbt':{
      workdir:__dirname,
      // docker images to run.
      // use -d to run without additional terminal.
      // --link and -e db= will be added automatically.
      // if it exposes a port, tester will automatically
      // wait for it to start listening before booting next.
      // use ; to add bash commands to be ran after image stops operating
      // e.g. '-p 3333:3333 well-app ; echo We are finished!; read'
      dockimages:['-p 3333:3333 --rm well-app'],
      // dockerfiles to be rebuilt when -fb is used
      // syntax: [image-tag] [path_to_dockerfile]
      dockbuilds:['well-app .'],
      // extra files to be erased on cleanup
      // uses prevention mechanisms to avoid self-destruction
      cleanups:['test/unit-db']
  }
}
```

Example of package.json entries:
```
{
  "scripts": {
    "start": "node app.js",
    "test": "./node_modules/.bin/mocha test/acceptance.test.js",
    "posttest": "./node_modules/.bin/mocha test/unit.test.js",
    "atest": "./node_modules/.bin/mocha test/acceptance.test.js",
    "utest": "./node_modules/.bin/mocha test/unit.test.js"
  }
}
```

---

It is completely safe to run while other dbt is in operation as it will stop and clean after the old one first.
You can also run clean manually when things go wrong:
```
npm test --args="[PROJECT_NAME] -clean"
```

dbs supported:
- mem (requires usage of seneca-db-listen)
- jsonfile (requires usage of seneca-db-listen)
- mongo
- redis
- postgres
- mysql

*** when no dbs specified, it tests them all

|  flag  |                           operation                               |
|--------|-------------------------------------------------------------------|
| -dbs   | specify dbs                                                       |
| -fd    | force docker pull                                                 |
| -fb    | force app build                                                   |
| -tu    | unit test only                                                    |
| -ta    | acceptance test only                                              |
| -nt    | no test, just run everything                                      |
| -man   | manual control and no log report                                  |
| -clean | clean up only                                                     |
| -ner   | never erase custom temp files on cleanup                          |
| -aer   | always erase custom temp files on cleanup                         |
| -timg  | tidy up images (rmi images with no name and no tag <none> <none>) |

e.g.

```
npm test --args="[PROJECT_NAME] -dbs mongo"
npm test --args="[PROJECT_NAME] -dbs mem mysql jsonfile -ta"
npm test --args="[PROJECT_NAME] -fd -fb"
```

Can be used to test same db several times.
Simply use multiplicity in any of the formats below:
```
npm test --args="[PROJECT_NAME] -dbs mongo-3x redis-7 mem mem"
npm test --args="[PROJECT_NAME] -dbs all-9000x"
```

---

Note: Unexpected End of Input in jsonfile-store test is a result of an internal bug and cannot be helped

---

**Dev only below**

Adding new DBs:

- @ run.sh
- 1) Add entry to DBS array
- @ image-check.sh
- 2) Check docker image name
- @ run.sh
- -> For SQL-based DBs you want to make init script that loads schema file. See postgres and mysql
- @ app
- 4) Make sure your app is using the db
- @ conf.js & where appropiate (e.g. mysql-init.sh)
- 5) Make sure it uses required data from app's options file (conf-obtain.sh may be handy)