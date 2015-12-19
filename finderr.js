'use strict'

var fs = require('fs')
var _ = require('lodash')

// takes in a string to look for in errors and reports the amount of occurences
var query = process.argv[2].toString().toLowerCase()
var results = {}

var logfolder = __dirname + '/log/fail' 
fs.stat(logfolder, function (err, res) {
  if (err) return console.log('log/fail folder not present - run sdbth')
  
  if (res.isDirectory()) {
    var entities = fs.readdirSync(logfolder)
    _.each(entities, function (entity) {
      var path = logfolder + '/' + entity
      var stat = fs.statSync(path)
      if (stat.isDirectory) {
        var db = entity.split('--')[0]
        if (!results[db]) results[db] = { found: 0, total: 1 }
        else results[db].total += 1
        var logs = fs.readdirSync(path)
        var foundInFolder = false
        _.each(logs, function (log) {
          if (!foundInFolder && log.indexOf('.err') > -1) {
            var contents = fs.readFileSync(path + '/' + log).toString().toLowerCase()
            if (contents.indexOf(query) > -1) {
              results[db].found += 1
              foundInFolder = true
            }
          } 
        })
      }
    })
  }
  _.each(Object.keys(results), function (db) {
    console.log(db + ': ' + results[db].found + ' / ' + results[db].total)
  })
})
