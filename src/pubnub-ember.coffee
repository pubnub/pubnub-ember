'use strict'

(($window, $ember, $PUBNUB) ->
  $window.PubNubEmber = $ember.ObjectController.extend(Ember.Evented, {
  	NAMESPACE: 'pubnub'
  	pubnub: null
  	pnstate: {}
  	cfg: null

  	init: ->
      throw 'no configuration `cfg` provided!' unless @get('cfg')
      PubNub = $PUBNUB.init(@get('cfg'))
      @get('pnstate')['_channels'] = []
      @get('pnstate')['_presence'] = {}
      @get('pnstate')['_presData'] = {}
      @set('pubnub', PubNub)

    emListChannels: -> @get('pnstate')['_channels'].slice 0
    emListPresence: (channel) -> @get('pnstate')['_presence'][channel]?.slice 0
    emPresenceData: (channel) -> @get('pnstate')['_presData'][channel] || {}

    emMsgEv: (channel) -> "pn-message:#{channel}"
    emPrsEv: (channel) -> "pn-presence:#{channel}"
        
    emPublish: (args) -> @get('pubnub')['publish'].apply @get('pubnub'), [args]

    _emInstallHandlers: (args) ->
      self    = @get('pubnub')
      pnstate = @get('pnstate')
      inst    = this

      oldmessage = args.message
      args.message = ->
        inst.trigger(inst.emMsgEv(args.channel), {
          message: arguments[0],
          env: arguments[1],
          channel: args.channel
        })
        oldmessage(arguments) if oldmessage
      
      oldpresence = args.presence
      args.presence = ->
        event = arguments[0]
        channel = args.channel
        if event.uuids
          self.each event.uuids, (uuid) ->
            state = if uuid.state then uuid.state else null
            uuid  = if uuid.uuid  then uuid.uuid else uuid
            pnstate['_presence'][channel] ||= []
            pnstate['_presence'][channel].push uuid if pnstate['_presence'][channel].indexOf(uuid) < 0
            pnstate['_presData'][channel] ||= {}
            pnstate['_presData'][channel][uuid] = state if state
        else
          if event.uuid && event.action
            pnstate['_presence'][channel] ||= []
            pnstate['_presData'][channel] ||= {}
            if event.action == 'leave'
              cpos = pnstate['_presence'][channel].indexOf event.uuid
              pnstate['_presence'][channel].splice cpos, 1 if cpos != -1
              delete pnstate['_presData'][channel][event.uuid]
            else
              pnstate['_presence'][channel].push event.uuid if pnstate['_presence'][channel].indexOf(event.uuid) < 0
              pnstate['_presData'][channel][event.uuid] = event.data if event.data
        inst.trigger inst.emPrsEv(args.channel), {
          event: event,
          message: arguments[1],
          channel: channel
        }
      args

    emSubscribe: (args) ->
      self    = @get('pubnub')
      pnstate = @get('pnstate')
      inst    = this
      inst._emInstallHandlers(args)
      pnstate['_channels'].push args.channel if pnstate['_channels'].indexOf(args.channel) < 0
      pnstate['_presence'][args.channel] ||= []
      self['subscribe'].apply @get('pubnub'), [args]

    emUnsubscribe: (args) ->
      self    = @get('pubnub')
      pnstate = @get('pnstate')
      inst    = this
      cpos = pnstate['_channels'].indexOf(args.channel)
      pnstate['_channels'].splice cpos, 1 if cpos != -1
      pnstate['_presence'][args.channel] = null
      inst.off inst.emMsgEv(args.channel)
      inst.off inst.emPrsEv(args.channel)
      self['unsubscribe'](args)
      
    emHistory: (args) ->
      self = @get('pubnub')
      inst = this
      args.callback = inst._emFireMessages args.channel
      self['history'] args

    emHereNow: (args) ->
      self = @get('pubnub')
      inst = this
      args = inst._emInstallHandlers(args)
      args.state = true
      args.callback = args.presence
      delete args.presence
      delete args.message
      self['here_now'](args)

    _emFireMessages: (realChannel) ->
      self = @get('pubnub')
      inst = this
      (messages, t1, t2) ->
        self.each messages[0], (message) ->
          inst.trigger inst.emMsgEv(realChannel), {
            message: message
            channel: realChannel
          }

    emWhereNow: (args) -> @get('pubnub')['where_now'](args)
    emState:    (args) -> @get('pubnub')['state'](args)

    emAuth:  -> @get('pubnub')['auth'].apply  @get('pubnub'), arguments
    emAudit: -> @get('pubnub')['audit'].apply @get('pubnub'), arguments
    emGrant: -> @get('pubnub')['grant'].apply @get('pubnub'), arguments
  })

  $ember.onLoad 'Ember.Application', ($app) ->
    $app.initializer(
      name: 'pubnub'
      initialize: (container, application) ->
        application.register('pubnub:main', application.PubNub, {singleton: true})
        application.inject('controller', 'pubnub', 'pubnub:main')
        application.inject('route', 'pubnub', 'pubnub:main')
    )

)(window, window.Ember, window.PUBNUB)
