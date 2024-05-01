_ = require 'lodash'
moment = require 'moment'
{find} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
import {map, filter, tap} from 'rxjs'

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp
      .pipe find.box() 
      .pipe find.volUp() 
      .pipe find.level()
      .pipe filter (i) ->
        i.entry? or i.exit?
      .subscribe console.log
  catch err
    console.error err
