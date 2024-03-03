Promise = require 'bluebird'
import {map} from 'rxjs'
import moment from 'moment'
Binance = require('../index').default

do ->
  try 
    broker = await new Binance()
    code = 'BTCUSDT'

    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '5'})
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
