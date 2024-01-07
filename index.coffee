{Readable} = require 'stream'
import moment from 'moment'
import fromEmitter from '@async-generators/from-emitter'
import {EventEmitter} from 'events'
import {readFile} from 'fs/promises'
import {MainClient, WebsocketClient} from 'binance'
{freqDuration} = require('algotrader/data').default

class Binance extends EventEmitter
  @api_key: process.env.BINANCE_API_KEY
  @rsa_key: do ->
    (await readFile '/tmp/binance/binance-private-key.pem').toString()
  @freqMap: (interval) ->
    map =
      '1': '1m'
      '5': '5m'
      '15': '15m'
      '30': '30m'
    return if interval of map then map[interval] else interval

  constructor: ->
    super()
    return do =>
      @client = new MainClient
        api_key: Binance.api_key
        api_secret: await Binance.rsa_key
        beautifyResponse: true
      @ws = new WebsocketClient
        api_key: Binance.api_key
        api_secret: await Binance.rsa_key
        beautify: true
      @ws
        .on 'open', ->
          console.log "binance ws opened"
        .on 'reconnected', ->
          console.log 'binance ws reconnected'
        .on 'error', console.error
      @

  historyKL: ({code, freq, start, end} = {}) ->
    code ?= 'BTCUSDT'
    freq ?= '1'
    end ?= moment()
    start ?= moment end
      .subtract freqDuration[freq]
    (await @client.getKlines 
      symbol: code
      interval: Binance.freqMap freq
      startTime: start.valueOf()
      endTime: end.valueOf())
      .map ([timestamp, open, high, low, close, volume, ...]) ->
        {code, freq, timestamp, open, high, low, close, volume}

  streamKL: ({code, freq} = {}) ->
    code ?= 'BTCUSDT'
    freq ?= '1'
    ret = new Readable
      objectMode: true
      read: ->
        @pause()
      destroy: =>
        @ws.closeAll false
    @ws
      .subscribeSpotKline code, Binance.freqMap freq
      .on 'message', (msg) ->
        {e, E, s, k} = JSON.parse msg
        if s == code
          ret.resume()
          ret.push
            code: code
            freq: freq
            timestamp: k.t
            high: k.h
            low: k.l
            open: k.o
            close: k.c
            volume: k.v
    ret

  data: ({code, beginTime, freq} = {}) ->
    code ?= 'BTCUSDT'
    freq ?= '1'
    stream = @streamKL 
      code: code
      freq: freq
    destroy = ->
      stream.destroy()
    history = []
    if beginTime?
      history = await @historyKL
        code: code
        freq: freq
        start: beginTime
    g = ->
      yield from history
      yield from await fromEmitter stream, onNext: 'data'
    {g, destroy}

export default Binance
