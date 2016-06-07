global.XMLHttpRequest = require('xhr2');
global.dataLayer = [];
var test = require('blue-tape');
var GeordiClient = require('../index');

test('Instantiate a client with default settings', function(t) {
  var geordi = new GeordiClient();
  t.equal(geordi.env, 'staging');
  t.equal(geordi.projectToken, 'unspecified');
  t.end()
});
test('Log without a valid project token', function(t) {
  var geordi = new GeordiClient({projectToken:''});
  geordi.logEvent('test event')
    .then(function(response){
      t.fail('invalid project token should not be logged');
      t.end()
    })
    .catch(function(error){
      t.pass(error);
      t.end()
    });
});