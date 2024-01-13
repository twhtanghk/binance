moment = require 'moment'
Binance = require('../index').default

debug = (obj) ->
  console.error JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Binance()

    {g, destroy} = await broker.dataKL
      start: moment().subtract week: 1
      freq: '1'
    for await i from g()
      i.date = new Date i.timestamp * 1000
      console.log i
  catch err
    console.error err
