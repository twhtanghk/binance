_ = require 'lodash'
moment = require 'moment'
{find} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
import {combineLatest, bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'

    ohlc = (await broker.dataKL {code: code, start: moment().subtract(day: 7), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp

    box = ohlc
      .pipe find.box() 
      .pipe filter (x) ->
        x['box']?[2] < 0.5

    volUp = ohlc
      .pipe find.volUp() 
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    (combineLatest [box, volUp])
      .pipe filter ([b, v]) ->
        b.timestamp <= v.timestamp and v.timestamp - b.timestamp <= 120 # 2 min
      .pipe map ([b, v]) ->
        if v.close < b.box[0]
          v.exit ?= []
          v.exit.push {id: 'boxBreakout', side: 'sell', price: v.close}
        else if v.close > b.box[1]
          v.entry ?= []
          v.entry.push {id: 'boxBreakout', side: 'buy', price: v.close}
        [b, v]
      .pipe filter ([b, v]) ->
        ((_.find v['entry'], id: 'boxBreakout')? or
        (_.find v['exit'], id: 'boxBreakout')?)
      .subscribe (x) ->
        console.log JSON.stringify x, null, 2
  catch err
    console.error err
