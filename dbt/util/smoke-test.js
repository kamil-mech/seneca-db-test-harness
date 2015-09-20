"use strict"
process.setMaxListeners(0)

var _      = require('lodash')
var assert = require('assert')

describe('smoke test', function(){

  it ('happy', function(done){
    var helper = require('./smoke-test-helper.js')(done)
    var si = helper.si

    si.use('user')

    ;si
      .make$('sys/user')
      .make$({
        nick:'u0',
        name:'n0',
        pass:'p0'
      })
      .save$(function(err, data1){
      assert.equal(err, null)
      assert.notEqual(data1, null)
      assert.equal(data1.nick, 'u0')
      assert.equal(data1.name, 'n0')
      assert.equal(data1.pass, 'p0')

    ;si.make$('sys/user').load$({name:'n0'}, function(err, data2){
      assert.equal(err, null)
      assert.notEqual(data2, null)
      assert.equal(data1.nick, data2.nick)
      assert.equal(data1.id, data2.id)

    ;si.make$('sys/user').list$(function(err, data3){
      assert.equal(err, null)
      assert.notEqual(data3, null)
      assert.notEqual(data3[0], null)
      assert.equal(data1.id, data3[0].id)
      assert.equal(data1.nick, data3[0].nick)

      done()
    }) }) })
  })
})