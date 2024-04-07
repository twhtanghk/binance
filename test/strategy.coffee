_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
{createLogger} = winston = require 'winston'
import {from, concatMap, fromEvent, tap, map, filter} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: winston.format.simple()
  transports: [ new winston.transports.Console() ]

if process.argv.length != 3
  logger.error 'node -r coffeescript/register -r esm test/strategy nShare'
  process.exit 1

watch = ({broker, market, code, freq, nShare}) ->
  opts =
    market: market
    code: code
    start: moment().subtract minute: 60 * parseInt freq
    freq: freq
  account = await broker.defaultAcc()
  (await broker.dataKL opts)
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
    .pipe skipDup 'timestamp'
    .pipe map (i) ->
      i.date = new Date i.timestamp * 1000
      i
    .pipe strategy.indicator()
    .pipe strategy.meanReversion()
    .pipe filter (i) ->
      'entryExit' of i
    .pipe tap logger.debug
    .pipe filter (i) ->
      # filter those history data
      moment()
        .subtract minute: 2 * parseInt freq
        .isBefore moment.unix i.timestamp
    .pipe filter (i) ->
      # close price change sharply or remain in flat
      i['close.stdev'] > i['close'] * 0.4 / 100 or
      i['close.stdev'] < i['close'] * 0.12 / 100 
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
      if not ret
        logger.info "#{JSON.stringify pos} #{share} #{nShare} #{ret}"
      ret
    .pipe tap logger.debug
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
      logger.info params
      try
        index = await account.placeOrder params
        await account.enableOrder index
      catch err
        logger.error err

do ->
  try 
    [..., nShare] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    freq = '5'
    broker = await new Binance()
    subscription = await watch {broker, market, code, freq, nShare}
    fromEvent broker.ws, 'reconnected'
      .subscribe ->
        subscription.unsubscribe()
        subscription = await watch {broker, market, code, freq, nShare}
  catch err
    logger.error err
