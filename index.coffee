_ = require 'lodash'
{Readable} = require 'stream'
import moment from 'moment'
import fromEmitter from '@async-generators/from-emitter'
import {EventEmitter} from 'events'
import {readFile} from 'fs/promises'
import {MainClient, WebsocketClient} from 'binance'
{Broker, freqDuration} = AlgoTrader = require('algotrader/rxData').default
{createLogger} = winston = require 'winston'
import {concat, tap, map, from, filter, fromEvent} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: winston.format.simple()
  transports: [ new winston.transports.Console() ]

class Order extends AlgoTrader.Order
  @SIDE:
    buy: 'BUY'
    sell: 'SELL'

  @TYPE:
    limit: 'LIMIT'

class Account extends AlgoTrader.Account
  constructor: ({broker}) ->
    super()
    @broker = broker
  position: ->
    balance = (acc, {coin, free}) ->
      acc[coin] = free
      acc
    (await @broker.client.getBalances())
      .map ({coin, free}) ->
        {coin, free: parseFloat free}
      .filter ({coin, free}) ->
        free != 0
      .reduce balance, {}
  historyOrder: ({code, beginTime, endTime}={}) ->
    code ?= 'ETHUSDT'
    beginTime ?= moment().subtract hour: 12
    endTime ?= moment()
    ret = []
    while beginTime.isBefore endTime
      next = moment beginTime
      next = next.add hour: 12
      next = if next.isBefore endTime then next else endTime
      ret.push from await @broker.client.getAllOrders 
        symbol: code
        startTime: beginTime.toDate().getTime()
        endTime: next.toDate().getTime()
      beginTime = next
    concat ...ret
  streamOrder: ->
    conn = await @broker.ws.subscribeSpotUserDataStream()
    fromEvent conn, 'message'
      .pipe map ({type, data}) ->
        JSON.parse data
      .pipe filter ({e}) ->
        e == 'executionReport'
      .pipe map (data) ->
        {s, S, i, o, f, q, p, X, O} = data
        code = s
        side = (_.invert Order.SIDE)[S]
        id = i
        type = (_.invert Order.TYPE)[o]
        timeInForce = f
        qty = parseFloat q
        price = parseFloat p
        status = X
        createTime = O / 1000
        {code, side, id, type, timeInForce, qty, price, status, createTime}
  enableOrder: (index) ->
    super index
    {code, side, type, timeInForce, qty, price} = @orderList[index]
    side = Order.SIDE[side]
    type = Order.TYPE[type] 
    timeInForce ?= 'GTC'
    timestamp = Date.now()
    quantity = parseFloat qty.toFixed 8
    price = parseFloat price.toFixed 8
    {orderId, status} = await @broker.client.submitNewOrder {symbol: code, side, type, timeInForce, quantity, price, timestamp}
    _.extend @orderList[index], {status, id: orderId}
  cancelOrder: ({id}) ->
    {code, id} = _.find @orderList, {id}
    await @broker.client.cancelOrder {symbol: code, orderId: id}

export class Binance extends Broker
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

  reqId: 0

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
    conn = @ws.subscribeSpotKline code, Binance.freqMap freq
    fromEvent conn, 'message'
      .pipe map ({data}) ->
        JSON.parse data
      .pipe filter ({e, E, s, k}) ->
        s == code and k.i == Binance.freqMap(freq)
      .pipe map ({e, E, s, k}) ->
        market: 'crypto'
        code: code
        freq: freq
        timestamp: k.t / 1000
        high: parseFloat k.h
        low: parseFloat k.l
        open: parseFloat k.o
        close: parseFloat k.c
        volume: parseFloat k.v

  unsubKL: ({code, freq}) ->
    key = "spot_kline_#{code.toLowerCase()}_#{freq}"
    @ws.close key, false

  # defined in env.BINANCE_API_KEY and BINANCE.RSA_KEY
  @ACCOUNT: null
  accounts: ->
    Binance.ACCOUNT ?= new Account broker: @
    [Binance.ACCOUNT]

  orderBook: ({market, code}) ->
    conn = @ws.subscribePartialBookDepths code, 10, 1000, 'spot'
    fromEvent conn, 'message'
      .pipe map ({data}) ->
        {bids, asks} = JSON.parse data
        market: market
        code: code
        bid: bids.map ([price, volume]) ->
          price = parseFloat price
          volume = parseFloat volume
          {price, volume}
        ask: asks.map ([price, volume]) ->
          price = parseFloat price
          volume = parseFloat volume
          {price, volume}

export default Binance

export position = (account, pair, entryExit, nShare) -> (obs) ->
  obs
    .pipe concatMap (x) ->
      from do -> await account.position()
        .pipe map (pos) ->
          [x, pos]
    .pipe filter ([x, pos]) ->
      bal = [
        pos[pair[0]] || 0
        pos[pair[1]] || 0
      ]
      {side, price} = entryExit
      total = bal[0] * price + bal[1]
      share = total / nShare
      ret = (side == 'buy' and bal[1] > share) or (side == 'sell' and bal[0] * price > share)
      logger.info JSON.stringify {pos, total, share, ret}, null, 2
      ret
    .pipe map ([x, pos]) ->
      x

export order = (account, pair, entryExit, nShare) -> (obs) ->
  obs
    .pipe concatMap (x) ->
      bal = [
        pos[pair[0]] || 0
        pos[pair[1]] || 0
      ]
      {side, price} = entryExit
      total = bal[0] * price + bal[1]
      share = total / nShare
      params =
        code: "#{pair[0]}#{pair[1]}"
        side: side
        type: 'limit'
        price: price
        qty: Math.floor(share * 1000 / price) / 1000
      (from do ->
        try
          index = await account.placeOrder params
          await account.enableOrder index
        catch err
          logger.error err
      )
        .pipe map ->
          params
