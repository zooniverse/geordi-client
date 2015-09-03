// Generated by CoffeeScript 1.9.3
(function() {
  var GeordiClient, ZooUserStringGetter,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  ZooUserStringGetter = require('zooniverse-user-string-getter');

  module.exports = GeordiClient = (function() {
    GeordiClient.prototype.GEORDI_STAGING_SERVER_URL = 'http://geordi.staging.zooniverse.org/api/events/';

    GeordiClient.prototype.GEORDI_PRODUCTION_SERVER_URL = 'http://geordi.zooniverse.org/api/events/';

    GeordiClient.prototype.defaultSubjectGetter = function() {
      return "(unknown)";
    };

    GeordiClient.prototype.defaultLastKnownCohortGetter = function() {
      return null;
    };

    GeordiClient.prototype.defaultZooUserIDGetter = function() {
      return null;
    };

    GeordiClient.prototype.defaultProjectToken = "unspecified";

    GeordiClient.prototype.getCurrentSubject = GeordiClient.defaultSubjectGetter;

    GeordiClient.prototype.getCurrentUserID = GeordiClient.defaultZooUserIDGetter;

    function GeordiClient(config) {
      this.logError = bind(this.logError, this);
      this.logEvent = bind(this.logEvent, this);
      this.buildEventData = bind(this.buildEventData, this);
      this.addCohortToEventData = bind(this.addCohortToEventData, this);
      this.addUserDetailsToEventData = bind(this.addUserDetailsToEventData, this);
      this.logToGeordi = bind(this.logToGeordi, this);
      if (!"server" in config) {
        config["server"] = "staging";
      }
      if ((!"projectToken" in config) || (!config["projectToken"] instanceof String) || (!config["projectToken"].length > 0)) {
        config["projectToken"] = this.defaultProjectToken;
      }
      if ((!"zooUserIDGetter" in config) || (!config["zooUserIDGetter"] instanceof Function)) {
        config["zooUserIDGetter"] = this.defaultZooUserIDGetter;
      }
      if ((!"subjectGetter" in config) || (!config["subjectGetter"] instanceof Function)) {
        config["subjectGetter"] = this.defaultSubjectGetter;
      }
      if (config["server"] === "production") {
        this.GEORDI_SERVER_URL = this.GEORDI_PRODUCTION_SERVER_URL;
      } else {
        this.GEORDI_SERVER_URL = this.GEORDI_STAGING_SERVER_URL;
      }
      if ("experimentServerClient" in config) {
        this.experimentServerClient = config["experimentServerClient"];
      }
      this.getCurrentSubject = config["subjectGetter"];
      this.getCurrentUserID = config["zooUserIDGetter"];
      this.projectToken = config["projectToken"];
      this.UserStringGetter = new ZooUserStringGetter(this.getCurrentUserID);
    }


    /*
    log event with Google Analytics
     */

    GeordiClient.prototype.logToGoogle = function(eventData) {
      return dataLayer.push({
        event: "gaTriggerEvent",
        project_token: eventData['projectToken'],
        user_id: eventData['userID'],
        subject_id: eventData['subjectID'],
        geordi_event_type: eventData['type'],
        classification_id: eventData['relatedID']
      });
    };


    /*
    log event with Geordi v2.1
     */

    GeordiClient.prototype.logToGeordi = function(eventData) {
      return $.ajax({
        url: this.GEORDI_SERVER_URL,
        type: 'POST',
        contentType: 'application/json; charset=utf-8',
        data: JSON.stringify(eventData),
        dataType: 'json'
      });
    };

    GeordiClient.prototype.addUserDetailsToEventData = function(eventData) {
      var eventualUserIdentifier;
      eventualUserIdentifier = new $.Deferred;
      this.UserStringGetter.getUserIDorIPAddress().then((function(_this) {
        return function(data) {
          if (data != null) {
            return _this.UserStringGetter.currentUserID = data;
          }
        };
      })(this)).fail((function(_this) {
        return function() {
          return _this.UserStringGetter.currentUserID = "(anonymous)";
        };
      })(this)).always((function(_this) {
        return function() {
          eventData['userID'] = _this.UserStringGetter.currentUserID;
          return eventualUserIdentifier.resolve(eventData);
        };
      })(this));
      return eventualUserIdentifier.promise();
    };

    GeordiClient.prototype.addCohortToEventData = function(eventData) {
      var eventualEventData;
      eventualEventData = new $.Deferred;
      this.experimentServerClient.getCohort().then((function(_this) {
        return function(cohort) {
          if (cohort != null) {
            eventData['cohort'] = cohort;
            return _this.experimentServerClient.currentCohort = cohort;
          }
        };
      })(this)).always(function() {
        return eventualEventData.resolve(eventData);
      });
      return eventualEventData.promise();
    };

    GeordiClient.prototype.buildEventData = function(type, related_id, subject_id) {
      var eventData;
      if (related_id == null) {
        related_id = null;
      }
      if (subject_id == null) {
        subject_id = this.getCurrentSubject();
      }
      eventData = {};
      eventData['browserTime'] = Date.now();
      eventData['projectToken'] = this.projectToken;
      eventData['subjectID'] = subject_id;
      eventData['type'] = type;
      eventData['relatedID'] = related_id;
      eventData['serverURL'] = location.origin;
      eventData['data'] = JSON.stringify({});
      eventData['errorCode'] = "";
      eventData['errorDescription'] = "";
      if (this.experimentServerClient != null) {
        eventData['experiment'] = this.experimentServerClient.ACTIVE_EXPERIMENT;
        if (this.experimentServerClient.currentCohort != null) {
          eventData['cohort'] = this.experimentServerClient.currentCohort;
        }
      }
      eventData['userID'] = "(anonymous)";
      return eventData;
    };


    /*
    This will log a user interaction both in the Geordi
    analytics API and in Google Analytics.
     */

    GeordiClient.prototype.logEvent = function(type, related_id, subject_id) {
      var eventData;
      if (related_id == null) {
        related_id = '';
      }
      if (subject_id == null) {
        subject_id = this.getCurrentSubject();
      }
      eventData = this.buildEventData(type, related_id, subject_id);
      return this.addUserDetailsToEventData(eventData).always((function(_this) {
        return function(eventData) {
          if ((_this.experimentServerClient == null) || _this.experimentServerClient.ACTIVE_EXPERIMENT === null || (_this.experimentServerClient.currentCohort != null)) {
            _this.logToGeordi(eventData);
            return _this.logToGoogle(eventData);
          } else {
            return _this.addCohortToEventData(eventData).always(function(eventData) {
              _this.logToGeordi(eventData);
              return _this.logToGoogle(eventData);
            });
          }
        };
      })(this));
    };


    /*
    This will log an error in Geordi only.
    In order to guarantee that this works, no new AJAX
    calls for cohort or user IP are initiated
     */

    GeordiClient.prototype.logError = function(error_code, error_description, type, related_id, subject_id) {
      var eventData;
      if (related_id == null) {
        related_id = '';
      }
      if (subject_id == null) {
        subject_id = this.getCurrentSubject();
      }
      eventData = buildEventData(type, related_id, subject_id);
      eventData['errorCode'] = error_code;
      eventData['errorDescription'] = error_description;
      if (this.UserStringGetter.currentUserID != null) {
        eventData['userID'] = this.UserStringGetter.currentUserID;
      } else {
        eventData['userID'] = this.UserStringGetter.ANONYMOUS;
      }
      return this.logToGeordi(eventData);
    };

    return GeordiClient;

  })();

}).call(this);
