# geordi-client
A JavaScript client for the [Geordi](https://github.com/zooniverse/geordi) user analytics capture engine.

This library simplifies the process of posting an event to Geordi.

To use it in your project, first type:

```
npm install --save zooniverse-geordi-client
```

This will save the geordi library dependency into your project.

Now, in your `app/index.coffee` file (for hem projects), or your first-loaded JavaScript file otherwise, load and configure Geordi. This example is in CoffeeScript:

```
# import any needed modules
Subject = require 'models/subject'
User = require 'zooniverse/lib/models/user'

# load the geordi client class
GeordiClient = require 'zooniverse-geordi-client'

# define callback functions that you will pass to Geordi to allow retrieval of current user ID or subject ID
checkZooUserID = ->
  User.current?.zooniverse_id

checkZooSubject = ->
  Subject.current?.zooniverseId

# instantiate the Geordi client into a variable
Geordi = new GeordiClient({
  "server": "staging"
  "projectToken": "serengeti"
  "zooUserIDGetter": checkZooUserID
  "subjectGetter": checkZooSubject
})
```
If necessary, this can be added into a setup file, as shown in Snapshot Serengeti [here](https://github.com/alexbfree/Serengeti/blob/converting-geordi-to-component/app/lib/geordi_and_experiments_setup.coffee). This linked example also shows how to initialize Geordi when using an experiment server such as the [Zooniverse Experiment Server](https://github.com/zooniverse/ZooniverseExperimentServer) as well. 

Once Geordi is loaded into your JavaScript namespace, you can log an event very simply to Geordi as follows in this one-line CoffeeScript example:
```
Geordi.logEvent 'classify'
```
This would log an event of `type` `"classify"`.

The `projectToken` will be set as specified in your configuration, the `userID` and `subjectID` will be automatically retrieved using your provided `zooUserIDGetter` and `subjectGetter` respectively, and the `serverURL` and `browserTime` will be set automatically based on the current time and the `location.origin`.

Alternatively, you can pass a parameter object instead of a string, to set multiple parameters at once:
```
Geordi.logEvent {
  'type': 'classify'
  'relatedID': '123-456'
  'subjectID': 'ASG00312'
}
```
This will log an event of `type` `"classify"` with a `relatedID` of `"123-456"` and a `subjectID` of `"ASG00312"`

The [`zooniverse-user-string-getter`](https://github.com/zooniverse/zooniverse-user-string-getter) library will be used to obtain the user ID string to pass to Geordi. 

You can also use this method to log web application or other errors to Geordi, as in this CoffeeScript example:

```
Geordi.logEvent {
  'type': 'error'
  'subjectID': 'ASG00312'
  'errorCode': '409'
  'errorDescription': 'Couldn't load subject'
}
```

Note, you do not have to use `type` `"error"` for errors.

The list of parameters supported by `logEvent` is: `userID`,`subjectID`,`relatedID`,`errorCode`,`errorDescription`,`projectToken`,`serverURL`,`experiment`,`cohort`,`type`,`browserTime` and `data`. These are all required to be non-zero length strings, except for `data` which must be an object, and `browserTime` which should be a Javascript date in number format, corresponding to a date and time no earlier than midnight, September 1st, 2015.
The only required field is `type`.

# A note on Experimental Server integration

Geordi and the Geordi Client are also designed to integrate with the [Zooniverse Experiment Server](https://github.com/zooniverse/ZooniverseExperimentServer). This not currently documented as the Experimental Server client code is about to undergo a major refactoring.
Refer to the Snapshot Serengeti codebase [here](https://github.com/alexbfree/Serengeti/blob/converting-geordi-to-component/app/lib/geordi_and_experiments_setup.coffee) to see how this can work, or talk to Alex Bowyer for more information.

# References

Please refer to the [Geordi documentation](https://github.com/zooniverse/geordi/blob/master/README.md) for more information on logging events to Geordi and the work this client does for you.