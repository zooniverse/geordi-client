global.XMLHttpRequest = require('xhr2');
global.dataLayer = [];
var test = require('blue-tape');
var GeordiClient = require('../index');

test('Instantiate a client with default settings', function(t) {
  var geordi = new GeordiClient();
  t.equal(geordi.env, 'staging');
  t.equal(geordi.projectToken, 'unspecified');
  t.end();
});
test('Instantiate a client with older settings', function(t) {
  var geordi = new GeordiClient({server: 'production'});
  t.equal(geordi.env, 'production');
  t.end();
});
test('Instantiate a client with an invalid environment', function(t) {
  var geordi = new GeordiClient({env: 'dev'});
  t.equal(geordi.env, 'staging', "env is staging");
  t.end();
});
test('Instantiate a client with unknown host', function(t) {
  GeordiClient.prototype.GEORDI_SERVER_URL.test = 'https://geordi.staging.zooniverse.org.uk/api/events/';
  var geordi = new GeordiClient({env: 'test'});
  var x = 3;
  geordi.logEvent('test event')
  .then(function(response){
    t.fail('invalid environment should not succeed');
  });
  x++
  t.equal(x, 4, 'Code continues after API error');
  geordi.logEvent('test event')
  .catch(function(error){
    t.pass(error);
    t.end();
  });
});
test('Log without a valid project token', function(t) {
  var geordi = new GeordiClient({projectToken:''});
  geordi.logEvent('test event')
    .then(function(response){
      t.fail('invalid project token should not be logged');
      t.end();
    })
    .catch(function(error){
      t.pass(error);
      t.end();
    });
});
test('Log with valid project token', function(t) {
  var geordi = new GeordiClient({projectToken: 'test/token'});
  geordi.logEvent('test event')
    .then(function(data){
      return JSON.parse(data);
    })
    .then(function(event){
      t.equal(event.projectToken, 'test/token', "correct project token");
      t.equal(event.type, 'test event', "correct event type");
      t.end();
    })
});
test('Update data on Geordi', function(t) {
  var geordi = new GeordiClient({projectToken: 'test/token'});
  geordi.update({projectToken: 'new/token'})
  t.equal(geordi.projectToken, 'new/token');
  t.end();
});
