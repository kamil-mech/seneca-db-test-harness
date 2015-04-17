# DBT Manager

**Also works with npm! See below**

You will need:
- Config file in .js format(because it's compatible with seneca-stores). See below.
- Set test, utest and atest scripts in package.json (and possibly posttest if you like). utest is unit-test and atest is acceptance-test. See below.
- Make sure your app is compatible with DBs used.

Example of config file using one app image and two DBs below this list:
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
      // if it exposes a port with -p, tester will automatically
      // wait for it to start listening before booting next.
      // use ; to add bash commands to be ran after image stops operating
      // e.g. '-p 3333:3333 well-app ; echo Oh no!; read'
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
    "utest": "./node_modules/.bin/mocha test/unit.test.js",
    "dbt": "bash node_modules/seneca-db-test-harness/dbt/run.sh options.js",
    "clean": "bash node_modules/seneca-db-test-harness/dbt/clean.sh options.js"
  }
}
```

---

```
bash run.sh [CONFIG_FILE] [FLAGS]
```

It is completely safe to run while other dbt is in operation as it will stop and clean after the old one first.
You can also run clean manually when things go wrong:
```
bash clean.sh [CONFIG_FILE (optional)] [FLAGS]
```

dbs supported:
- mem
- jsonfile
- mongo
- redis
- postgres
- mysql

*** when no dbs specified, it tests them all

| flag  |                           operation                            |   used in  |
|-------|----------------------------------------------------------------|------------|
| -dbs  | specify dbs                                                    |    run     |
| -fd   | force docker pull                                              |    run     |
| -fb   | force app build                                                |    run     |
| -tu   | unit test only                                                 |    run     |
| -ta   | acceptance test only                                           |    run     |
| -nt   | no test, just run everything                                   |    run     |
| -auto | run through all without manual control and produce log report  |    run     |
| -ner  | never erase custom temp files on cleanup                       | run, clean |
| -aer  | always erase custom temp files on cleanup                      | run, clean |

e.g.

```
bash db-test.sh -dbs mongo
bash db-test.sh -dbs mem mysql jsonfile -ta
bash db-test.sh -fd -fb
```

Can be used to test same db several times!
```
bash db-test.sh -dbs mongo mongo mongo
```

Or use multiplicity in any of formats below!
```
bash db-test.sh -dbs mongo-3x redis-7 mem mem
```

**Works with npm!**

Lets say you add entry in package.json scripts:
```
"dbt": "bash node_modules/seneca-db-test-harness/dbt/run.sh options.js",
```
Where last argument is the path and filename of your options file

Then all the stuff simply works:

```
npm run dbt
npm run dbt --args="-dbs redis mongo -fb -tu" 
npm run dbt --args="-dbs mongo mongo mongo -fb -tu" 
npm run dbt --args="bash db-test.sh -dbs mongo-3x redis-7 mem"
```

You can add clean command as well to make your life easier:
```
"clean": "bash node_modules/seneca-db-test-harness/dbt/clean.sh options.well.js"
```

```
npm run clean
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
- 4) Go to your app and config it to connect to the DB
- @ conf.js & where appropiate
- 5) Make sure it uses required data from app's options file