ZooUserStringGetter = require 'zooniverse-user-string-getter'

module.exports = class GeordiClient

  GEORDI_STAGING_SERVER_URL:
    'http://geordi.staging.zooniverse.org/api/events/'
  GEORDI_PRODUCTION_SERVER_URL:
    'http://geordi.zooniverse.org/api/events/'

  gettingCohort: false

  defaultSubjectGetter: ->
    "(unknown)"

  defaultLastKnownCohortGetter: ->
    null

  defaultZooUserIDGetter: ->
    null

  defaultProjectToken: "unspecified"

  getCurrentSubject: @defaultSubjectGetter
  getCurrentUserID: @defaultZooUserIDGetter

  constructor: (config) ->
    config["server"] = "staging" if not "server" of config
    config["projectToken"] = @defaultProjectToken if (not "projectToken" of config) or (not config["projectToken"] instanceof String) or (not config["projectToken"].length>0)
    config["zooUserIDGetter"] = @defaultZooUserIDGetter if (not "zooUserIDGetter" of config) or (not config["zooUserIDGetter"] instanceof Function)
    config["subjectGetter"] = @defaultSubjectGetter if (not "subjectGetter" of config) or (not config["subjectGetter"] instanceof Function)
    if config["server"] == "production"
      @GEORDI_SERVER_URL = @GEORDI_PRODUCTION_SERVER_URL
    else
      @GEORDI_SERVER_URL = @GEORDI_STAGING_SERVER_URL
    @experimentServerClient = config["experimentServerClient"] if "experimentServerClient" of config
    @getCurrentSubject = config["subjectGetter"]
    @getCurrentUserID = config["zooUserIDGetter"]
    @projectToken = config["projectToken"]
    @UserStringGetter = new ZooUserStringGetter(@getCurrentUserID)

  ###
  log event with Google Analytics
  ###
  logToGoogle: (eventData) ->
    dataLayer.push {
      event: "gaTriggerEvent"
      project_token: eventData['projectToken']
      user_id: eventData['userID']
      subject_id: eventData['subjectID']
      geordi_event_type: eventData['type']
      classification_id: eventData['relatedID']
    }

  ###
  log event with Geordi v2.1
  ###
  logToGeordi: (eventData) =>
    $.ajax {
      url: @GEORDI_SERVER_URL,
      type: 'POST',
      contentType: 'application/json; charset=utf-8',
      data: JSON.stringify(eventData),
      dataType: 'json'
    }

  ###
  add the user's details to the event data - but only use IP getting service if we don't currently have a way to identify the user
  ###
  addUserDetailsToEventData: (eventData) =>
    eventualEventData = new $.Deferred
    if @UserStringGetter.currentUserID==@UserStringGetter.ANONYMOUS || @UserStringGetter.currentUserID==@UserStringGetter.UNAVAILABLE
      @UserStringGetter.getUserIDorIPAddress()
      .then (data) =>
        if data?
          console.log "getUserID etc from String getter got an ID of "
          console.log data
          if data!=@UserStringGetter.currentUserID
            console.log " which is now being set as current user ID"
            @UserStringGetter.currentUserID = data
          else
            console.log " but no need to set it as it already has that value"
      .fail =>
        console.log "attempt to get userID etc from string getter failed, setting current user id to "+@UserStringGetter.UNAVAILABLE
        @UserStringGetter.currentUserID = @UserStringGetter.UNAVAILABLE
      .always =>
        eventData['userID'] = @UserStringGetter.currentUserID
        eventualEventData.resolve eventData
    else
      eventData['userID'] = @UserStringGetter.currentUserID
      eventualEventData.resolve eventData
    eventualEventData.promise()

  addCohortToEventData: (eventData) =>
    eventualEventData = new $.Deferred
    @experimentServerClient.getCohort()
    .then (cohort) =>
      if cohort?
        eventData['cohort'] = cohort
        @experimentServerClient.currentCohort = cohort
    .always ->
      eventualEventData.resolve eventData
    eventualEventData.promise()

  buildEventData: (eventData = {}) =>
    eventData['browserTime'] = Date.now()
    eventData['projectToken'] = @projectToken
    eventData['serverURL'] = location.origin
    eventData['errorCode'] = ""
    eventData['errorDescription'] = ""
    if @experimentServerClient?
      eventData['experiment'] = @experimentServerClient.ACTIVE_EXPERIMENT
      if @experimentServerClient.currentCohort?
        eventData['cohort'] = @experimentServerClient.currentCohort
    if @UserStringGetter.currentUserID?
      eventData['userID'] = @UserStringGetter.currentUserID
    else
      eventData['userID'] = @UserStringGetter.ANONYMOUS
    eventData

  updateEventDataFromParameterObject: (parameterObject, eventData = {}) ->
    for field in ["userID","subjectID","relatedID","errorCode","errorDescription","projectToken","serverURL","experiment","cohort","type"]
      if field of parameterObject and typeof(parameterObject[field])=="string" and parameterObject[field].length>0
        eventData[field] = parameterObject[field]
    if "data" of parameterObject and typeof(parameterObject["data"])=="object"
      eventData["data"]=JSON.stringify(parameterObject["data"])
    if "browserTime" of parameterObject and typeof(parameterObject["browserTime"])=="number" and parameterObject["browserTime"]>1441062000000 # Sep 1, 2015
      eventData["browserTime"]=parameterObject["browserTime"]
    eventData

  ###
  This will log a user interaction both in the Geordi
  analytics API and in Google Analytics.
  ###
  logEvent: (parameter) =>
    eventData = @buildEventData()
    if typeof(parameter)=="string"
      # single parameter assumed to be type
      eventData["type"] = parameter
    else if typeof(parameter)=="object"
      # get params
      if not ("type" of parameter and typeof(parameter.type)=="string" and parameter.type.length>0)
        eventData["errorCode"] = "GCP01"
        eventData["errorDescription"] = "missing 'type' when calling logEvent in Geordi client"
        eventData["type"] = "error"
      else
        eventData = @updateEventDataFromParameterObject parameter, eventData
      if not ("subjectID" of eventData and typeof(parameter.subjectID)=="string" and parameter.subjectID.length>0)
        eventData["subjectID"] = @getCurrentSubject()
    else
      eventData["errorCode"] = "GCP03"
      eventData["errorDescription"] = "bad parameter passed to logEvent in Geordi Client"
      eventData["type"] = "error"
    if not "data" of eventData
      eventData["data"]={}
    if (not "userID" of eventData) || eventData["userID"]==@UserStringGetter.ANONYMOUS || eventData["userID"]==@UserStringGetter.UNAVAILABLE
      @addUserDetailsToEventData(eventData)
      .always (eventData) =>
        if not eventData["userID"]?
          eventData["userID"]=@UserStringGetter.UNAVAILABLE
        if (not @experimentServerClient?) || @experimentServerClient.ACTIVE_EXPERIMENT==null || @experimentServerClient.currentCohort? || @experimentServerClient.experimentCompleted
          eventData["data"]["loggingWithoutExternalRequest"]=true
          eventData["data"]["experimentServerClientPresence"]=!!@experimentServerClient?
          eventData["data"]["experimentDefined"]=!!@experimentServerClient.ACTIVE_EXPERIMENT
          eventData["data"]["experimentHasCurrentCohort"]=!!@experimentServerClient.currentCohort?
          if eventData["data"]["experimentHasCurrentCohort"]
            eventData["data"]["experimentCurrentCohort"]=@experimentServerClient.currentCohort
          eventData["data"]["experimentMarkedComplete"]=!!@experimentServerClient.experimentCompleted
          @logToGeordi eventData
          @logToGoogle eventData
        else
          if !@gettingCohort
            eventData["data"]["loggingWithoutExternalRequest"]=false
            eventData["data"]["cohortRequestAlreadyInProgress"]=true
            @gettingCohort = true
            @addCohortToEventData(eventData)
            .always (eventData) =>
              @logToGeordi eventData
              @logToGoogle eventData
              @gettingCohort = false
          else
            eventData["data"]["loggingWithoutExternalRequest"]=true
            eventData["data"]["cohortRequestAlreadyInProgress"]=false
            @logToGeordi eventData
            @logToGoogle eventData
    else
      if "userID" not of eventData
        eventData["data"]["missingUserID"]=true
        eventData["userID"]=@UserStringGetter.UNAVAILABLE
      @logToGeordi eventData
      @logToGoogle eventData