_ = require 'lodash'
import moment from 'moment'
Binance = require('../index').default
{ohlc} = require('algotrader/analysis').default
strategy = require('algotrader/rxStrategy').default

do ->
  try 
    broker = await new Binance()
    code = 'ETHUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '5'})
      .pipe ohlc.skipDup 'timestamp'
      .pipe strategy.indicator()
      .subscribe (i) ->
        console.log _.extend i, date: moment.unix i.timestamp
  catch err
    console.error err
