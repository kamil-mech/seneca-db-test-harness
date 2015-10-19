var async = require('async');

var calls = [];

// async recursion!
var func = function(some, cb){
  var self = this;
  // 1 sec delay
  setTimeout(function() {
    // condition modifier
    some += 1;
    console.log(some);
    // stop if condition met
    if (some == 10) return cb(null, some);
    // else call again
    func(some, function(err, some){
      return cb(null, some)
    });
  }, 1000);
}

calls.push(func.bind(null, 0));

async.series(calls, function(){
  console.log('end');
});