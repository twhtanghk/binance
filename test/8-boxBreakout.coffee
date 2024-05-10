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

    (combineLatest ohlc, box, volUp)
      .pipe filter ([o, b, v]) ->
        b.timestamp <= v.timestamp
      .pipe map ([o, b, v]) ->
        if o.close < b[0]
          o.exit ?= []
          o.exit.push {id: 'boxBreakout', side: 'sell', price: o.close}
        else if o.close > b[1]
          o.entry ?= []
          o.exit.push {id: 'boxBreakout', side: 'buy', price: o.close}
      .subscribe (x) ->
        console.log JSON.stringify x, null, 2
  catch err
    console.error err
