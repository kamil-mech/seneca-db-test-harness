TODO

#quick setup

- pull [this well app fork](https://github.com/kamil-mech/well/tree/sdbth-4)
- inside it `npm install`
- inside it `mv options.example.js options.well.js`
- pull this repo, so that both folders are side by side
- inside this `npm install`
- beside both folders, create `sdbth.conf` file and add configuration(see below)
- example use: `node sdbth.js well -fb -dbs mem-5 mysql postgresql level jsonfile mongo redis`

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