_ = require 'lodash'
moment = require 'moment'
{find, indicator, meanReversion} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
import Binance, {position, order} from '../index.js'
logger = require('../logger').default
parse = require('./args').default
import {Subject, from, combineLatest, bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    broker = new Binance()
    {test, ohlc} = opts = parse()
    {pair, start, end, freq} = ohlc
    {nShare} = opts.order
    code = "#{pair[0]}#{pair[1]}"
    balance = {}
    balance[pair[0]] = 0
    balance[pair[1]] = 1000
    account = if test then broker.testAcc({balance}) else await broker.defaultAcc()
    logger.info opts

    src = (params) ->
      if test 
        await broker.historyKL params
      else
        await broker.dataKL params
    
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
        logger.info x

    (await src {code, start, end, freq})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp
      .subscribe criteria
  catch err
    logger.error err
