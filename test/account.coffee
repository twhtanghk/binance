Binance = require('../index').default

do ->
  try 
    broker = await new Binance()

    console.log await broker.accounts()[0].position()
  catch err
    console.error err
