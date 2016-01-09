'use strict'

module.exports = {
  setTitle: function (title) {
    process.stdout.write(
      String.fromCharCode(27) + "]0;" + title + String.fromCharCode(7)
    )
  }
}
