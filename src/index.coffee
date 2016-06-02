ZooUserStringGetter = require 'zooniverse-user-string-getter'

module.exports = class GeordiClient

  GEORDI_STAGING_SERVER_URL:
    'https://geordi.staging.zooniverse.org/api/events/'
  GEORDI_PRODUCTION_SERVER_URL:
    'https://geordi.zooniverse.org/api/events/'

  gettingCohort: false

  _defaultSubjectGetter: ->
    "(N/A)"

  _defaultSubjectGetterParameter: ->
    "(N/A)"

  _defaultLastKnownCohortGetter: ->
    null

  _defaultZooUserIDGetter: ->
    null

  _defaultProjectToken: "unspecified"

  _getCurrentSubject: @_defaultSubjectGetter
  _getCurrentUserID: @_defaultZooUserIDGetter

  constructor: (config) ->
    config["server"] = "staging" if not "server" of config
    config["projectToken"] = @_defaultProjectToken if (not "projectToken" of config) or (not config["projectToken"] instanceof String) or (not config["projectToken"].length>0)
    config["zooUserIDGetter"] = @_defaultZooUserIDGetter if (not "zooUserIDGetter" of config) or (not config["zooUserIDGetter"] instanceof Function)
    config["subjectGetter"] = @_defaultSubjectGetter if (not "subjectGetter" of config) or (not config["subjectGetter"] instanceof Function)
    config["subjectGetterParameter"] = @_defaultSubjectGetterParameter if (not "subjectGetterParameter" of config)
    if config["server"] == "production"
      @GEORDI_SERVER_URL = @GEORDI_PRODUCTION_SERVER_URL
    else
      @GEORDI_SERVER_URL = @GEORDI_STAGING_SERVER_URL
    @experimentServerClient = config["experimentServerClient"] if "experimentServerClient" of config
    @_getCurrentSubject = config["subjectGetter"]
    @_getCurrentSubjectParameter = config["subjectGetterParameter"]
    @_getCurrentUserID = config["zooUserIDGetter"]
    @_getCurrentUserIDParameter = config["zooUserIDGetterParameter"]
    @_projectToken = config["projectToken"]
    @UserStringGetter = new ZooUserStringGetter(@_getCurrentUserID,@_getCurrentUserIDParameter)

  ###
  log event with Google Analytics
  ###
  _logToGoogle: (eventData) ->
    if dataLayer?
      dataLayer.push {
        event: "gaTriggerEvent"
        project_token: eventData['projectToken']
        user_id: eventData['userID']
        subject_id: eventData['subjectID']
        geordi_event_type: eventData['type']
        classification_id: eventData['relatedID']
      }
    else
      throw new Error "Warning: Google Tag Manager script not found - Geordi is not logging to Google Analytics."

  ###
  log event with Geordi v2.1
  ###
  _logToGeordi: (eventData) =>
    $.ajax {
      url: @GEORDI_SERVER_URL,
      type: 'POST',
      contentType: 'application/json; charset=utf-8',
      data: JSON.stringify(eventData),
      dataType: 'json'
    }

  ###
  add the user's details to the event data
  ###
  _addUserDetailsToEventData: (eventData) =>
    eventualEventData = new $.Deferred
    if (!@UserStringGetter.currentUserID)||@UserStringGetter.currentUserID==@UserStringGetter.ANONYMOUS
      @UserStringGetter.getUserID()
      .then (data) =>
        if data?
          if data!=@UserStringGetter.currentUserID
            @UserStringGetter.currentUserID = data
      .always =>
        eventData['userID'] = @UserStringGetter.currentUserID
        eventualEventData.resolve eventData
    else
      eventData['userID'] = @UserStringGetter.currentUserID
      eventualEventData.resolve eventData
    eventualEventData.promise()

  _addCohortToEventData: (eventData) =>
    eventualEventData = new $.Deferred
    @experimentServerClient.getCohort()
    .then (cohort) =>
      if cohort?
        eventData['cohort'] = cohort
        @experimentServerClient.currentCohort = cohort
    .always ->
      eventualEventData.resolve eventData
    eventualEventData.promise()

  _buildEventData: (eventData = {}) =>
    eventData['browserTime'] = Date.now()
    eventData['projectToken'] = @_projectToken
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

  _updateEventDataFromParameterObject: (parameterObject, eventData = {}) ->
    # copy all string & numeric data across
    for field in ["userID","subjectID","relatedID","errorCode","errorDescription","projectToken","serverURL","experiment","cohort","type","userSeq","sessionNumber","eventNumber","userAgent","clientIP"]
      if field of parameterObject and typeof(parameterObject[field])=="string" and parameterObject[field].length>0
        eventData[field] = parameterObject[field]
    # copy 'data' field across to event data
    if "data" of parameterObject
      # ensure it is an object
      if typeof(parameterObject["data"])=="string"
        newData=JSON.parse(parameterObject["data"])
      else
        newData=parameterObject["data"]
      # merge new data object with existing data object (if not empty)
      if eventData["data"]?
        if typeof(eventData["data"])=="string"
          eventData["data"]=JSON.parse(eventData["data"])
        for k, v of newData
          eventData["data"][k]=v
      else
        eventData["data"]=newData
      # convert back to string
      eventData["data"]=JSON.stringify(eventData["data"])
    # copy browser time across (the only other non-string, non-numeric field)
    if "browserTime" of parameterObject and typeof(parameterObject["browserTime"])=="number" and parameterObject["browserTime"]>1441062000000 # Sep 1, 2015
      eventData["browserTime"]=parameterObject["browserTime"]
    eventData

  ###
  This will log a user interaction both in the Geordi
  analytics API and in Google Analytics.
  ###
  logEvent: (parameter) =>
    eventData = @_buildEventData()
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
        eventData = @_updateEventDataFromParameterObject parameter, eventData
      if not ("subjectID" of eventData and typeof(parameter.subjectID)=="string" and parameter.subjectID.length>0)
        eventData["subjectID"] = @_getCurrentSubject()
    else
      eventData["errorCode"] = "GCP02"
      eventData["errorDescription"] = "bad parameter passed to logEvent in Geordi Client"
      eventData["type"] = "error"
    @_addUserDetailsToEventData(eventData)
    .always (eventData) =>
      if not eventData["userID"]?
        eventData["userID"]=@UserStringGetter.ANONYMOUS
      if (!@experimentServerClient?) || (!@experimentServerClient.shouldGetCohort(eventData["userID"]))
        @_logToGeordi eventData
        @_logToGoogle eventData
      else
        if !@gettingCohort
          @gettingCohort = true
          @_addCohortToEventData(eventData)
          .always (eventData) =>
            @_logToGeordi eventData
            @_logToGoogle eventData
            @gettingCohort = false
        else
          @_logToGeordi eventData
          @_logToGoogle eventData
