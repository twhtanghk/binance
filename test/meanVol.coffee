_ = require 'lodash'
moment = require 'moment'
{format, transports, createLogger} = require 'winston'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {min, max, skip, bufferCount, zip, concat, from, concatMap, fromEvent, tap, map, filter} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: format.combine format.timestamp(), format.simple()
  transports: [ new transports.Console() ]

if process.argv.length != 4
  logger.error 'node -r coffeescript/register -r esm test/meanVol.coffee freq nShare'
  process.exit 1

watch = ({broker, market, code, freq, nShare}) ->
  opts =
    market: market
    code: code
    start: moment().subtract week: 1
    end: moment()
    freq: freq
  account = await broker.defaultAcc()
  ohlc = (await broker.dataKL opts)
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
    .pipe skipDup 'timestamp'
    .pipe map (i) ->
      i.date = new Date i.timestamp * 1000
      i
    .pipe strategy.indicator()
    .pipe strategy.meanReversion()
    .pipe filter ({entryExit}) ->
      entryExit?
    .pipe filter (x) ->
      x['volume'] / x['volume.mean'] > 5
    .pipe filter (i) ->
      # filter those history data
      moment()
        .subtract minute: 2 * parseInt freq
        .isBefore moment.unix i.timestamp
    .subscribe (x) ->
      logger.debug JSON.stringify x, null, 2
      {ETH, USDT} = pos = await account.position()
      {buy, sell} = quote = await broker.quickQuote {market, code}
      total = ETH * buy + USDT
      share = total / nShare
      side = x.entryExit[0].side
      price = quote[side]
      params =
        code: opts.code
        side: side
        type: 'limit'
        price: price
        qty: Math.floor(share * 1000 / price) / 1000
      logger.debug JSON.stringify pos, null, 2
      logger.debug JSON.stringify quote, null, 2
      logger.debug JSON.stringify params, null, 2
      try
        index = await account.placeOrder params
        await account.enableOrder index
      catch err
        console.error err

do ->
  try 
    [..., freq, nShare] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    broker = await new Binance()
    subscription = await watch {broker, market, code, freq, nShare}
    fromEvent broker.ws, 'reconnected'
      .subscribe ->
        subscription.unsubscribe()
        subscription = await watch {broker, market, code, freq, nShare}
  catch err
    console.error err
