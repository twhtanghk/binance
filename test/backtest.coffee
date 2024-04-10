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
  logger.error 'node -r coffeescript/register -r esm test/backtest.coffee freq nShare'
  process.exit 1

watch = ({broker, market, code, freq}) ->
  opts =
    market: market
    code: code
    start: moment().subtract week: 1
    end: moment()
    freq: freq
  ohlc = (await broker.historyKL opts)
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
    .subscribe (x) ->
      logger.debug JSON.stringify x, null, 2

do ->
  try 
    [..., freq] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    broker = await new Binance()
    subscription = await watch {broker, market, code, freq}
    fromEvent broker.ws, 'reconnected'
      .subscribe ->
        subscription.unsubscribe()
        subscription = await watch {broker, market, code, freq}
  catch err
    console.error err
