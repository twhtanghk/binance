_ = require 'lodash'
moment = require 'moment'
{find, indicator, meanReversion} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
import {combineLatest, bufferCount, map, filter, tap} from 'rxjs'

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'

    ohlc = (await broker.dataKL {code: code, start: moment().subtract(minute: 60), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp

    mean = ohlc
      .pipe indicator()
      .pipe meanReversion()
      .pipe map (x) ->
        if x['close'] > x['close.mean'] + 2 * x['close.stdev']
          x.exit ?= []
          x.exit.push {id: 'mean', side: 'sell', price: x['close']}
        else if x['close'] < x['close.mean'] - 2 * x['close.stdev']
          x.enter ?= []
          x.enter.push {id: 'mean', side: 'buy', price: x['close']}
        x
      .pipe filter (x) ->
        x.enter? or x.exit?

    volUp = ohlc
      .pipe find.volUp() 
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    (combineLatest [mean, volUp])
      .pipe filter ([m, v]) ->
        m.timestamp == v.timestamp
      .subscribe (x) ->
        console.log JSON.stringify x, null, 2
  catch err
    console.error err
