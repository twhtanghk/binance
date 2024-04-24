_ = require 'lodash'
import moment from 'moment'
Binance = require('../index').default

do ->
  try 
    broker = await new Binance()
    code = 'ETHUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '5'})
      .subscribe (i) ->
        console.log _.extend i, date: moment.unix i.timestamp
  catch err
    console.error err
