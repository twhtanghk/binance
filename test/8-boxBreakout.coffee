_ = require 'lodash'
moment = require 'moment'
{find} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
import Binance, {position, order} from '../index.js'
logger = require('../logger').default
parse = require('./args').default
import {Subject, combineLatest, bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    criteria = new Subject()
    broker = await new Binance()
    {test, ohlc} = opts = parse()
    {pair, start, end, freq} = ohlc
    {nShare} = opts.order
    code = pair[0] + pair[1]
    balance = {}
    balance[pair[0]] = 0
    balance[pair[1]] = 1000
    account = if test then broker.testAcc({balance, ohlc: criteria}) else await broker.defaultAcc()
    logger.info opts

    src = (params) ->
      if test
        await broker.historyKL params
      else
        await broker.dataKL params

    box = criteria
      .pipe find.box() 
      .pipe filter (x) ->
        x['box']?[2] < 0.5

    volUp = criteria
      .pipe find.volUp() 
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    (combineLatest [box, volUp])
      .pipe filter ([b, v]) ->
        b.timestamp <= v.timestamp and v.timestamp - b.timestamp <= 120 # 2 min
      .pipe map (indicator) ->
        [b, v] = indicator
        entryExit = null
        if v.close < b.box[0]
          entryExit = {id: 'boxBreakout', side: 'sell', price: v.close}
        else if v.close > b.box[1]
          entryExit = {id: 'boxBreakout', side: 'buy', price: v.close}
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
    console.error err
