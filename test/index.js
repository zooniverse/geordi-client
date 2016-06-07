var test = require('blue-tape');
var GeordiClient = require('../index');

test('Instantiate a client with default settings', function(t) {
  var geordi = new GeordiClient({projectToken: ''});
  t.equal(geordi.GEORDI_SERVER_URL, 'https://geordi.staging.zooniverse.org/api/events/');
  t.equal(geordi._projectToken, 'unspecified');
  t.end()
});