_ = require 'lodash'
moment = require 'moment'
{find} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
import {combineLatest, distinct, bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'

    ohlc = (await broker.dataKL {code: code, start: moment().subtract(day: 7), freq: '1'})
      .pipe distinct (x) ->
        x.timestamp
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp

    box = ohlc
      .pipe find.box() 
      .pipe filter (x) ->
        x['box']?[2] < 0.5

    volUp = ohlc
      .pipe find.volUp() 
      .pipe filter (x) ->
        x['volume.trend'] == 1

    level = ohlc
      .pipe find.level()
      .pipe filter (x) ->
        ((_.find x['entry'], id: 'level.support')? or
        (_.find x['exit'], id: 'level.resistance')?)
        
    (combineLatest box, level, volUp)
      .pipe filter ([b, l, v]) ->
        b.timestamp <= l.timestamp and l.timestamp <= v.timestamp
      .subscribe (x) ->
        console.log JSON.stringify x, null, 2
  catch err
    console.error err
