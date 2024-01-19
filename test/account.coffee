Binance = require('../index').default

do ->
  try 
    broker = await new Binance()

    console.log JSON.stringify (await broker.accounts()[0].position()), null, 2
    console.log JSON.stringify (await broker.accounts()[0].historyOrder()), null, 2
  catch err
    console.error err
