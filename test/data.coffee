moment = require 'moment'
Binance = require('../index').default

debug = (obj) ->
  console.error JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Binance()

    {g, destroy} = await broker.dataKL
      start: moment().subtract day: 1
      freq: '1'
    for await i from g()
      console.log i
  catch err
    console.error err
