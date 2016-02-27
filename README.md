# Seneca-db-test-harness 0.4.1

Tested on **Ubuntu 15.10** with **Node 0.10.38**

---

## About

SDBTH automates the process of testing seneca-stores against seneca applications. It deploys both database and application in docker containers using DBT Manager. DBT Manager is the core of SDBTH and it serves the purpose of deployment, linking, testing, monitoring and reporting. After containers are deployed, DBT Manager runs tests. When tests are ran, it monitors for errors. Many tests can be scheduled at once. At the end it reports the results and provides tools aiding debugging like `why.js` and `finderr.js`.

Video presentation:

https://www.youtube.com/watch?v=VYFfys8LwSk

## Quick Setup

- Pull [this well app fork](https://github.com/kamil-mech/well/tree/sdbth-4)
- Inside it `npm install`
- Inside it `mv options.example.js options.well.js`
- Pull this repo, so that both folders are side by side
- Inside this `npm install`
- Beside both folders, create `sdbth.conf` file and add configuration(see below)
- Example use: `node sdbth.js well -fb -dbs mem-5 mysql postgresql level jsonfile mongo redis`
- In case of problems with Redis, see [this issue](https://github.com/kamil-mech/seneca-db-test-harness/issues/2)

**sdbth.conf**
```
'use strict'

module.exports = {
  well: {
    optionsfile: __dirname + '/well/options.example.js',
    // docker images to run.
    // --link and -e db= will be added automatically.
    // if it exposes a port in dockerfile, tester will automatically
    // wait for it to start listening before booting next.
    dockimages: [
      { name: 'well-app', path: __dirname + '/well/.', testTarget: true }
    ],
    deploymode: 'series', // 'series' or 'parallel'
    testpath: __dirname + '/well/' // it will npm test in this location
  }
}
```

## Contribution
Adding support for a particular database is as complex as the database itself. In general, schema-based stores are the hardest to harness. In order to add support for a new database, follow some of these steps:
- Ensure such `seneca-?-store exists` on `npm` or create one.
- Find a corresponding docker image on [docker hub](https://hub.docker.com/).
- Find out its default port.
- Create new file named the same as databaseb in `dbs`. This will be the definition of database-specific constants and related meta information.
- Populate the file with appropiate database-specific information. For examples, look at `mem.json`, `mongo.json` and `mysql.json` in `dbs` folder.
- In case of stores like `mem`, `jsonfile` and `level` DBT Manager doesn't do much at the moment. All You have to do is mark the store as local. It's up to the app to use [seneca-store-listen](https://github.com/kamil-mech/seneca-store-listen). This will be upgraded in the future.
- In case of stores like `mongo` and `redis`. Local: false, image name and default port should be provided.
- In case of stores like `mysql` and `postgresql` situation becomes complicated. `run` points to a bash file which is ran INSTEAD of regular docker deployment. `init` points to a bash file which is ran when store is listening. This becomes handy when schema needs to be preloaded. `reads` takes in listed fields in specified order from app's options file defined in `conf`. Then it feeds it to the `run` script in said order as $ args. `computes` is a special type of field which has hardcoded assignment. Fields listed in `computes` are forwarded to `init` script as $ args after `reads` fields. Currently only supports `dbip`, as it was required to connect to db container. If more info were to be exposed, do CTRL + F `computes` in `sdbth.js` and make appropiate changes following the example of `dbip`.
- `testargs` are necessary for smoke test to pass. These are usually similar to values of `reads`. They are strongly coupled with setup in `run`. So far they are only used in `mysql` and `postgresql`.
- Ensure that the app it's tested against is Dockerized and that it actually uses the store. It may be handy to disable default store (mem-store) when initialising seneca:`var seneca = require('seneca')({default_plugins:{'mem-store':false}})`.
- Ensure this setup runs flawless (100% success) in at least 10 runs, otherwise it can be considered to have a major bug.
- Remember to use `-debug` flag when necessary.
- For a handy example check out **Quick Setup** above.
- If unclear, stuck and frustrated for too long - understand how it works. (see below)

## Operation Flow
This section explains how DBT Manager works internally. Reading the source may be necessary to add support for a very complicated database.

**#TODO**