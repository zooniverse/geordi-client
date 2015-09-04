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

Once Geordi is loaded into your JavaScript namespace, you can log events to Geordi as follows in this CoffeeScript example:
```
Geordi.logEvent 'classify','123-456','ASG00312'
```
This would log an event of type `"classify"`, with relatedID `"123-456"` and subject ID of `"ASG00312"`
The first two parameters are compulsory, the subjectID parameter is optional and the provided `subjectGetter` will be used if it is omitted.
The [`zooniverse-user-string-getter`](https://github.com/zooniverse/zooniverse-user-string-getter) library will be used to obtain the user ID string to pass to Geordi. 

You can log errors to Geordi as in this CoffeeScript example:
```
Geordi.logError "409", "Couldn't POST subject", "error", "123-456", "ASG00312"
```
This would log an event of type `error`, with error code `409` an error description `Couldn't POST subject`. The related ID would be passed as `"123-456"` and the subject ID set to `"ASG00312"`.
The first three parameters are compulsory, the relatedID and subjectID parameters are optiona.
The provided `subjectGetter` will be used if subjectID is omitted.
Related ID will be set to NULL if omitted.
The [`zooniverse-user-string-getter`](https://github.com/zooniverse/zooniverse-user-string-getter) library will be used to obtain the user ID string to pass to Geordi. 

# A note on current status

These functions currently do not support overriding of the newly added fields in Geordi v2.1, namely `browserTime`, `serverURL`, `data`, `sessionNumber` and `eventNumber`.
However, the `serverURL` and `browserTime` fields will be set automatically and passed to Geordi when you call `logEvent` or `logError`.
This client will soon be updated to support the new fields and use a more versatile parameter format.

# A note on Experimental Server integration

Geordi and the Geordi Client are also designed to integrate with the [Zooniverse Experiment Server](https://github.com/zooniverse/ZooniverseExperimentServer). This not currently documented as the Experimental Server client code is about to undergo a major refactoring.
Refer to the Snapshot Serengeti codebase [here](https://github.com/alexbfree/Serengeti/blob/converting-geordi-to-component/app/lib/geordi_and_experiments_setup.coffee) to see how this can work, or talk to Alex Bowyer for more information.

# References

Please refer to the [Geordi documentation](https://github.com/zooniverse/geordi/blob/master/README.md) for more information on logging events to Geordi and the work this client does for you.