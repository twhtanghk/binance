{Readable} = require 'stream'
import moment from 'moment'
import fromEmitter from '@async-generators/from-emitter'
import {EventEmitter} from 'events'
import {readFile} from 'fs/promises'
import {MainClient, WebsocketClient} from 'binance'
{Broker, freqDuration} = AlgoTrader = require('algotrader/data').default

class Account extends AlgoTrader.Account
  constructor: ({broker}) ->
    super()
    @broker = broker
  position: ->
    await @broker.client.getBalances()
    
class Binance extends Broker
  @api_key: process.env.BINANCE_API_KEY
  @rsa_key: do ->
    (await readFile process.env.BINANCE_RSA_KEY).toString()
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
      @ws = new WebsocketClient
        api_key: Binance.api_key
        api_secret: await Binance.rsa_key
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
      .subtract freqDuration[freq].dataFetched
    ret = []
    while true
      curr = await @client.getKlines
        symbol: code
        interval: Binance.freqMap freq
        startTime: start.valueOf()
        endTime: end.valueOf()
      if curr.length != 0
        [..., last] = ret = ret.concat curr
        [timestamp, ...] = last
        start = moment timestamp
          .add freqDuration[freq].duration
      else
        break
    ret
      .map ([timestamp, open, high, low, close, volume, ...]) ->
        {
          market: 'crypto'
          code: code
          freq: freq
          timestamp: timestamp / 1000
          open: parseFloat open
          high: parseFloat high
          low: parseFloat low
          close: parseFloat close
          volume: parseFloat volume
        }

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
            market: 'crypto'
            code: code
            freq: freq
            timestamp: k.t / 1000
            high: parseFloat k.h
            low: parseFloat k.l
            open: parseFloat k.o
            close: parseFloat k.c
            volume: parseFloat k.v
    ret
  accounts: ->
    [new Account broker: @]

export default Binance
