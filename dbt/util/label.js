"use strict";

var fs = require('fs')

// inputs:
// - npm test --args="value -flag"
// - docker run -p 27017:27017 well-app
// - bash here/there/script.sh

// outputs:
// - [0]test
// - [0]well-app
// - [0]script.sh
// * output increments unless -nc or -bnc flag is used

module.exports = function() {
  return {
    make: function(argv) {

      var nc = false // no change flag
      if (argv[0] === '-nc' || argv[0] === '-bnc') nc = true

      // take last string if it doesn't contain --

      var i 
      for (i = argv.length - 1; i >= 0; i--) {
        if (argv[i].indexOf('--') == -1) break
      }

      // drop slashes
      var raw = argv[i].toString().split('/')
      raw = raw[raw.length - 1]

      // ensure index file
      var folder_path = __dirname + '/temp/'
      if (!fs.existsSync(folder_path)) fs.mkdirSync(folder_path)
      var file_path = folder_path + raw + '.cfg'

      // determine index by incrementation
      var index = 0
      if (fs.existsSync(file_path)) {
        index = fs.readFileSync(file_path)
        if (nc !== true) index++
      }
      if (nc !== true) fs.writeFileSync(file_path, index)

      // generate label
      var label = '[' + index + ']' + raw

      return label
    }
  }
}

// Both compatible with bash and node. For bash use, prefix input with -b
if (process.argv[2] === '-bnc' || process.argv[2] === '-b') {
  var argv = process.argv
  argv.shift()
  argv.shift()
  console.log(module.exports().make(argv))
}