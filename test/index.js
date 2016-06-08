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
