require( 'es6-promise').polyfill()
ZooUserStringGetter = require 'zooniverse-user-string-getter'

module.exports = class GeordiClient

  GEORDI_SERVER_URL:
    staging: 'https://geordi.staging.zooniverse.org/api/events/'
    production: 'https://geordi.zooniverse.org/api/events/'
  
  GEORDI_DATABASE_FIELDS: [
      "userID"
      "subjectID"
      "relatedID"
      "errorCode"
      "errorDescription"
      "projectToken"
      "serverURL"
      "experiment"
      "cohort"
      "type"
      "userSeq"
      "sessionNumber"
      "eventNumber"
      "userAgent"
      "clientIP"
    ]

  # Default config parameters
  gettingCohort: false
  env: 'staging'
  projectToken: 'unspecified' 
  subjectGetter: () ->
    "(N/A)"
  zooUserIDGetter: () ->
    null
  zooUserIDGetterParameter: null

  constructor: (config = {}) ->
    @update config
    @UserStringGetter = new ZooUserStringGetter @zooUserIDGetter, @zooUserIDGetterParameter
  
  update: (config = {}) ->
    if config.server && @GEORDI_SERVER_URL[config.server]
      config.env = config.server
      delete config.server
      
    for property, value of config
      @[property] = value
      

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
  _logToGeordi: (eventData) ->
    request = new XMLHttpRequest()
    request.open "POST", @GEORDI_SERVER_URL[@env]
    request.setRequestHeader "Content-Type", "application/json; charset=utf-8"
    
    new Promise (resolve, reject) ->

      request.onload = () ->
          if request.status == 200
            resolve request.response
          else
            reject Error request.statusText

      request.onerror = () ->
          reject Error "Network Error"
      
      request.send JSON.stringify eventData

  ###
  add the user's details to the event data
  ###
  _addUserDetailsToEventData: (eventData) ->
    new Promise (resolve, reject) =>
      if (!@UserStringGetter.currentUserID) || (@UserStringGetter.currentUserID == @UserStringGetter.ANONYMOUS)
        @UserStringGetter.getUserID()
        .then (data) =>
          if data?
            if data!=@UserStringGetter.currentUserID
              @UserStringGetter.currentUserID = data
          @UserStringGetter.currentUserID
        .then ( userID ) ->
          eventData['userID'] = userID
          resolve eventData
      else
        eventData['userID'] = @UserStringGetter.currentUserID
        resolve eventData

  _addCohortToEventData: (eventData) ->
    new Promise (resolve, reject) =>
      @experimentServerClient.getCohort()
      .then (cohort) =>
        if cohort?
          eventData['cohort'] = cohort
          @experimentServerClient.currentCohort = cohort
      .then () ->
        resolve eventData

  _buildEventData: (eventData = {}) ->
    eventData['browserTime'] = Date.now()
    eventData['projectToken'] = @projectToken
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
    for field in @GEORDI_DATABASE_FIELDS
      if parameterObject[field]? and typeof(parameterObject[field])=="string" and parameterObject[field].length>0
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
        eventData["subjectID"] = @subjectGetter()
    else
      eventData["errorCode"] = "GCP02"
      eventData["errorDescription"] = "bad parameter passed to logEvent in Geordi Client"
      eventData["type"] = "error"
    @_addUserDetailsToEventData(eventData)
      .then (eventData) =>
        if not eventData["userID"]?
          eventData["userID"]=@UserStringGetter.ANONYMOUS
        if (!@experimentServerClient?) || (!@experimentServerClient.shouldGetCohort(eventData["userID"]))
          promise = @_logToGeordi eventData
          @_logToGoogle eventData
        else
          if !@gettingCohort
            @gettingCohort = true
            @_addCohortToEventData(eventData)
            .then (eventData) =>
              promise = @_logToGeordi eventData
              @_logToGoogle eventData
              @gettingCohort = false
          else
            promise = @_logToGeordi eventData
            @_logToGoogle eventData
        promise
    
