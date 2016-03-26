# Seneca-db-test-harness 0.4.1

Tested on **Ubuntu 15.10** with **Node 0.10.38**

---

## About

SDBTH automates the process of testing seneca-stores against seneca applications. It deploys both database and application in docker containers using DBT Manager. DBT Manager is the core of SDBTH and it serves the purpose of deployment, linking, testing, monitoring and reporting. After containers are deployed, DBT Manager runs tests inside test target container. When tests are ran, it monitors for errors. Many tests can be scheduled at once. At the end it reports the results and provides tools aiding debugging like `why.js` and `finderr.js`.

Video presentation:

https://www.youtube.com/watch?v=VYFfys8LwSk

## Quick Setup

- Pull [this well app fork](https://github.com/kamil-mech/well/tree/sdbth-4)
- Inside it `npm install`
- Inside it `mv options.example.js options.well.js`
- Pull this repo, so that both folders are side by side
- Inside this `npm install`
- Beside both folders, create `sdbth.conf` file and add configuration(see below)
- Example use: `node main.js well -fb -dbs mem-5 mysql postgresql level jsonfile mongo redis`
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
    deploymode: 'series', // 'series' or 'parallel',
    knownWarnings: [
      "deprecated"
    ]
  }
}

```

## Flags


| Flag | Description   |
| ---- | ------------- |
| -dbs | dbs to be tested, including multiplicity |
| -all | tests all dbs, except dbnames provided after the flag. x=n will cause each db to be tested n times |
| -fb  | force build of app image |
| -fd  | force docker pull of db images |
| -ns  | no smoke test, deploy only db, then pause |
| -na  | no app, deploy only db and run smoke test, then pause |
| -nt  | no test, deploy only db and app, then pause |
| -nm  | no monitors, deploy everything, then pause |
| -nw  | no windows, do not spawn subprocesses in separated terminals |
| -nwo | same as -nw, but also hide output from subprocesses |
| -cln | removes docker bloat using rm -rf |
| -debug | shows literally everything that happens |

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
- `-debug` is your friend.
- For a handy example check out **Quick Setup** above.
- If unclear, stuck and frustrated for too long - understand how it works. (see below)

## Operation Flow
This section explains how DBT Manager works internally. Reading the source may be necessary to add support for a very complicated database.

- main.js spawns sdbth.js and monitors it
- Args are processed and assigned to variables.
- Conf and options are loaded based on args.
- Store tests are scheduled based on multiplicity of params after -dbs flag.
- Each scheduled test starts off with binded main function.
- First, main attempts to deploy the db.
- Db-specific constants are loaded.
- If DB is local(like mem, jsonfile or level), then it does nothing in this section.
- If DB has an init script(like mysql or postgresql) then it ensures all the reads values are fed into deployment.
- If DB is regular (like mongo or redis) then it just uses constants.
- Once all is set, main runs deployment in a new window(if -nw or -nwo flags are not used).
- All subprocesses are using spawmon.js, which is generating files in /temp and /log based on stdout and stderr of the process. spawmon.js sets up monitoring and then runs pop.js, which takes care of deployment logic.
- All pop.js instances are fed an info object which contains plenty of meta info, like db constants, dblabel and so on.
- pop.js tries to pull, build and run docker images or just runs test accordingly to info it is fed.
- Main waits for pop.js to finish pulling, building. starting and initialising the image. Then, it may also run the init script if it is present, feeding it computes fields.
- Then smoke test - called sanity check - is run. All it does is trying to connect to db using testargs and attempt basic save and load.
- Then main attempts to run the app image in similar fashion to db image.
- It tries to rebuild the image if -fb is fed into it. Then it deploys it, linking db docker container to it.
- Then it waits for the image to be up and ready. This is determined using curl and asynchronous recursion.
- Finally, the tests are run inside test target container and fed all necessary information.
- Monitors go up and scan for err, fin and log files made by instances of spawmon.js. If they detect a fin, then success is assumed. If they detect an err, then failure is assumed.
- Cleanup follows, making sure docker containers and subprocesses are destroyed. temp folder is emptied. If -cln flag is used, docker bloat is erased (handy with mongo).
- Logfiles are moved to log folder and organised.
- Main continues with stores until it finishes testing them all.
- When finished testing, it summarizes the test.
- Log folder is now ready for investigation.

