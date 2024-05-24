_ = require 'lodash'
moment = require 'moment'
{find, indicator, meanReversion} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
import Binance, {position, order} from '../index.js'
{createLogger, format, transports} = require 'winston'
import {timer, concatMap, from, combineLatest, bufferCount, map, filter, tap} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: format.simple()
  transports: [ new transports.Console() ]

do ->
  try
    broker = await new Binance()
    pair = [
      'ETH'
      'USDT'
    ]
    code = "#{pair[0]}#{pair[1]}"
    account = await broker.defaultAcc()
    nShare = 5

    ohlc = (await broker.historyKL {code: code, start: moment().subtract(day: 1), end: moment(), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp
      .pipe concatMap (x) ->
        timer 100
          .pipe map ->
            x

    volUp = ohlc
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    mean = ohlc
      .pipe indicator()
      .pipe meanReversion()

    (combineLatest [mean, volUp])
      .pipe filter ([m, v]) ->
        m.timestamp == v.timestamp
      .pipe map (indicator) ->
        [m, v] = indicator
        entryExit = null
        if m['close'] > m['close.mean'] + 2 * m['close.stdev']
          entryExit = {id: 'mean', side: 'sell', price: m['close']}
        else if m['close'] < m['close.mean'] - 2 * m['close.stdev']
          entryExit = {id: 'mean', side: 'buy', price: m['close']}
        {indicator, entryExit}
      .pipe filter (x) ->
        x.entryExit?
      .pipe position account, pair, nShare
#      .pipe order account, pair, nShare
      .subscribe (x) ->
        logger.info JSON.stringify x, null, 2
  catch err
    logger.error err
