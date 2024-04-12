_ = require 'lodash'
moment = require 'moment'
{format, transports, createLogger} = require 'winston'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {bufferCount, zip, concat, from, concatMap, fromEvent, tap, map, filter} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: format.combine format.timestamp(), format.simple()
  transports: [ new transports.Console() ]

if process.argv.length != 4
  logger.error 'node -r coffeescript/register -r esm test/scalp backtest|watch freq'
  process.exit 1

nShare = parseInt process.env.NSHARE
plRatio = JSON.parse process.env.PLRATIO

decision = ({market, code, ohlc, account}) ->
  ohlc
    .pipe skipDup 'timestamp'
    .pipe map (i) ->
      i.date = new Date i.timestamp * 1000
      i
    .pipe strategy.indicator()
    .pipe tap (x) -> logger.debug JSON.stringify x
  size = 20
  box = ohlc
    .pipe bufferCount size, 1
    .pipe map (i) ->
      [
        _.minBy(i, 'low').low
        _.maxBy(i, 'high').high
      ]
  zip ohlc, (concat (new Array size - 1), box)
    .pipe map ([i, box]) ->
      _.extend i, {box}
    .pipe bufferCount 2, 1
    .pipe filter ([prev, curr]) ->
      logger.debug "close.stdev.stdev: #{curr['close.stdev.stdev']}"
      curr['close.stdev.stdev'] < 1.1
    .pipe filter ([prev, curr]) ->
      # check if price breakout exists
      ret = false
      if prev['box']?
        [low, high] = prev['box']
        logger.debug "box: #{[low, high]}"
        ret = curr['close'] < low or curr['close'] > high
      ret
    .pipe filter ([prev, curr]) ->
      # check if volume increased
      logger.debug "volume.trend: #{curr['volume.trend']}"
      curr['volume.trend'] == 1
    .pipe map ([prev, curr]) ->
      [low, high] = prev['box']
      side = switch true
        when curr['close'] < low then 'sell'
        when curr['close'] > high then 'buy'
      curr.entryExit ?= []
      curr.entryExit.push
        strategy: 'scalp'
        side: side
        plPrice: [
          null
          low
        ]
      [prev, curr]
    .pipe tap (x) -> logger.debug JSON.stringify x
    .pipe concatMap (i) ->
      from do -> await account.position()
        .pipe map (pos) ->
          {i, pos}
    .pipe concatMap ({i, pos}) ->
      from do -> await broker.quickQuote {market, code}
        .pipe map (quote) ->
          {i, pos, quote}
    .pipe filter ({i, pos, quote}) ->
      {ETH, USDT} = pos
      ETH ?= 0
      USDT ?= 0
      {buy, sell} = quote
      total = ETH * buy + USDT
      share = total / nShare
      side = i.entryExit[0].side
      price = quote[side]
      ret = (side == 'buy' and USDT > share) or (side == 'sell' and ETH * price > share)
      logger.debug "#{JSON.stringify pos} #{share} #{nShare} #{ret}"
      ret

backtest = ({broker, market, code, freq}) ->
  opts =
    market: market
    code: code
    start: moment().subtract week: 1
    end: moment()
    freq: freq
  ohlc = await broker.historyKL opts
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
  account = await broker.defaultAcc()  
  decision {market, code, ohlc, account}
    .subscribe (x) ->
      logger.debug JSON.stringify x, null, 2

watch = ({broker, market, code, freq}) ->
  opts =
    market: market
    code: code
    start: moment().subtract minute: 60 * parseInt freq
    freq: freq
  ohlc = await broker.dataKL opts
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
  account = await broker.defaultAcc()
  decision {market, code, ohlc, account}
    .pipe filter ([prev, curr]) ->
      # filter those history data
      moment()
        .subtract minute: 2 * 5
        .isBefore moment.unix curr.timestamp
    .subscribe ({i, pos, quote}) ->
      {ETH, USDT} = pos
      ETH ?= 0
      USDT ?= 0
      {buy, sell} = quote
      total = ETH * buy + USDT
      share = total / nShare
      side = i.entryExit[0].side
      price = quote[side]
      params =
        code: opts.code
        side: side
        type: 'limit'
        price: price
        qty: Math.floor(share * 1000 / price) / 1000
      logger.debug JSON.stringify params
###
      try
        index = await account.placeOrder params
        await account.enableOrder index
      catch err
        console.error err
###

do ->
  try 
    [..., action, freq] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    freq = '5'
    broker = await new Binance()
    subscription = await {backtest, watch}[action] {broker, market, code, freq}
    fromEvent broker.ws, 'reconnected'
      .subscribe ->
        subscription.unsubscribe()
        subscription = await {backtest, watch}[action] {broker, market, code, freq}
  catch err
    console.error err
