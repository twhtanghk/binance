_ = require 'lodash'
moment = require 'moment'
{find} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
import {bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 7), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp
      .pipe find.box() 
      .pipe find.volUp() 
      .pipe find.level()
      .pipe bufferCount 3, 1
      .pipe filter (i) ->
        [prev, curr, last] = i
        last['volume.trend'] == 1 and 
        curr['box'][2] < 0.5 and 
        ((_.find prev['entry'], id: 'level.support')? or
        (_.find prev['exit'], id: 'level.resistance')?)
      .subscribe console.log
  catch err
    console.error err
