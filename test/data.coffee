Binance = require('../index').default

debug = (obj) ->
  console.error JSON.stringify obj, null, 2

do ->
  try 
    broker = await new Binance()

    debug await broker.historyKL()
  catch err
    console.error err
