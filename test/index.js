var test = require('blue-tape');
var GeordiClient = require('../index');

test('Instantiate a client with default settings', function(t) {
  var geordi = new GeordiClient();
  t.equal(geordi.env, 'staging');
  t.equal(geordi.projectToken, 'unspecified');
  t.end()
});