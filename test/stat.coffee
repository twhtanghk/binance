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

if process.argv.length != 2
  logger.error 'node -r coffeescript/register -r esm test/stat.coffee'
  process.exit 1

watch = ({broker, market, code, freq, nShare}) ->
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
  ohlc
    .pipe skip 40
    .pipe min (a, b) ->
      a['close.stdev.stdev'] - b['close.stdev.stdev']
    .subscribe (x) ->
      logger.info "min: #{JSON.stringify x}"
  ohlc
    .pipe max (a, b) ->
      a['close.stdev.stdev'] - b['close.stdev.stdev']
    .subscribe (x) ->
      logger.info "max: #{JSON.stringify x}"
  ohlc
    .subscribe (x) ->

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
    console.error err
