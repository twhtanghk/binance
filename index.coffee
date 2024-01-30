{Readable} = require 'stream'
import moment from 'moment'
import fromEmitter from '@async-generators/from-emitter'
import {EventEmitter} from 'events'
import {readFile} from 'fs/promises'
import {MainClient, WebsocketClient} from 'binance'
{Broker, freqDuration} = AlgoTrader = require('algotrader/rxData').default
import {map, from, filter} from 'rxjs'

class Account extends AlgoTrader.Account
  constructor: ({broker}) ->
    super()
    @broker = broker
  position: ->
    (await @broker.client.getBalances())
      .filter (i) ->
        i.free != '0'
      .map ({coin, free}) ->
        coin: coin
        free: parseFloat free
  placeOrder: (opts) ->
    (await @broker.client.submitNewOrder opts)
  historyOrder: ->
    (await @broker.client.getAllOrders symbol: 'ETHBTC')

class Binance extends Broker
  @api_key: process.env.BINANCE_API_KEY
  @rsa_key: do ->
    (await readFile process.env.BINANCE_RSA_KEY).toString()
  @freqMap: (interval) ->
    bmap =
      '1': '1m'
      '5': '5m'
      '15': '15m'
      '30': '30m'
    return if interval of bmap then bmap[interval] else interval

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
        .on 'message', (msg) =>
          try
            @next msg
          catch err
            console.log err
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
    from ret.map ([timestamp, open, high, low, close, volume, ...]) ->
      market: 'crypto'
      code: code
      freq: freq
      timestamp: timestamp / 1000
      open: parseFloat open
      high: parseFloat high
      low: parseFloat low
      close: parseFloat close
      volume: parseFloat volume

  streamKL: ({code, freq} = {}) ->
    code ?= 'BTCUSDT'
    freq ?= '1'
    @ws
      .subscribeSpotKline code, Binance.freqMap freq
    kl = filter ({e, E, s, k}) ->
      s == code and k.i == Binance.freqMap(freq)
    transform = map ({e, E, s, k}) ->
      market: 'crypto'
      code: code
      freq: freq
      timestamp: k.t / 1000
      high: parseFloat k.h
      low: parseFloat k.l
      open: parseFloat k.o
      close: parseFloat k.c
      volume: parseFloat k.v
    @pipe kl, transform

  accounts: ->
    [new Account broker: @]

export default Binance
