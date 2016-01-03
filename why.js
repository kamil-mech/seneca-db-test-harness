'use strict'

var fs = require('fs')
var _ = require('lodash')

// takes in a string which is a folder name in log/fail e.g. mongo--5
var target = process.argv[2]
var results = {}

var logfolder = __dirname + '/log/fail/' + target
fs.stat(logfolder, function (err, res) {
  if (err) return console.log(logfolder + ' folder not present - run sdbth')
  
  if (res.isDirectory()) {
    var logs = fs.readdirSync(logfolder)
    _.each(logs, function (log) {
      if (log.indexOf('.err') > -1) {
        console.log('\n' + log + '\n---\n')
        console.log(fs.readFileSync(logfolder + '/' + log).toString())
        console.log()
      }
    })
  }
})
