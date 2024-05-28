_ = require 'lodash'
moment = require 'moment'
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import Binance, {position, order} from '../index.js'
logger = require('./logger').default
parse = require('./args').default
import {from, concatMap, fromEvent, tap, map, filter} from 'rxjs'
import {inspect} from 'util'

do ->
  try 
    [..., nShare] = process.argv
    broker = await new Binance()
    {test, ohlc} = opts = parse()
    {pair, start, end, freq} = ohlc
    {nShare} = opts.order
    code = pair[0] + pair[1]
    account = if test then broker.testAcc() else await broker.defaultAcc()
    logger.info inspect opts
    
    src = (params) ->
      if test
        await broker.historyKL params
      else
        await broker.dataKL params

    (await src {code, start, end, freq})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp
      .pipe strategy.indicator()
      .pipe strategy.meanReversion()
      .pipe filter (x) ->
        x.entryExit?
      .pipe map (x) ->
        {side} = x.entryExit[0]
        _.extend x, entryExit:
          id: 'meanMinMax'
          side: side
          price: x.close
      .pipe filter (i) ->
        # close price change sharply or remain in flat
        i['close.stdev'] > i['close'] * 0.4 / 100 or i['close.stdev'] < i['close'] * 0.12 / 100 
      .pipe position account, pair, nShare
      .pipe order account, pair, nShare
      .subscribe (x) ->
        logger.info inspect x
  catch err
    logger.error err
