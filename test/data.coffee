#Promise = require 'bluebird'
import {map} from 'rxjs'
import moment from 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{ohlc} = require('algotrader/analysis').default
console.log ohlc

do ->
  try 
    broker = await new Binance()
    code = 'ETHUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '5'})
      .pipe ohlc.skipDup 'timestamp'
      .pipe strategy.indicator()
      .subscribe (i) ->
        i.date = new Date(i.timestamp * 1000)
        console.log i

###
    Promise
      .delay 1000
      .then ->
        broker.unsubKL {code: code, freq: '1d'}
###
  catch err
    console.error err
