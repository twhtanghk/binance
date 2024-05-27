_ = require 'lodash'
moment = require 'moment'
{find, indicator, meanReversion} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
import Binance, {position, order} from '../index.js'
{createLogger, format, transports} = require 'winston'
import {Subject, from, combineLatest, bufferCount, map, filter, tap} from 'rxjs'
parse = require('./args').default
import {inspect} from 'util'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: format.simple()
  transports: [ new transports.Console() ]

do ->
  try
    broker = new Binance()
    {test, ohlc} = opts = parse()
    {pair, start, end, freq} = ohlc
    {nShare} = opts.order
    code = "#{pair[0]}#{pair[1]}"
    account = if test then broker.testAcc() else await broker.defaultAcc()
    logger.info inspect opts

    src = (params) ->
      if test 
        await broker.historyKL params
      else
        await broker.dataKL params
    
    ohlc = (await src {code, start, end, freq})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp

    criteria = new Subject()

    volUp = criteria
      .pipe find.volUp()
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    mean = criteria
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
      .pipe order account, pair, nShare
      .subscribe (x) ->
        logger.info inspect x

      ohlc.subscribe criteria
  catch err
    logger.error err
