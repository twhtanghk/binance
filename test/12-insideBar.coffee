import moment from 'moment'
strategy = require('algotrader/rxStrategy').default
Binance = require('../index').default

do ->
  try 
    broker = await new Binance()
    code = 'ETHUSDT'
    (await broker.dataKL {code: code, start: moment().subtract(day: 1), freq: '5'})
      .pipe strategy.insideBar()
      .subscribe (i) ->
        i.date = new Date(i.timestamp * 1000)
        console.log i
  catch err
    console.error err
