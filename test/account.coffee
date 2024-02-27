Binance = require('../index').default

do ->
  try 
    broker = await new Binance()
    account = await broker.defaultAcc()
    console.log JSON.stringify (await account.position()), null, 2
    (await account.historyOrder()) 
      .subscribe console.log
    #account.placeOrder code: 'ETHUSDT', market: 'crypto', price: 2000, qty: 0.01
  catch err
    console.error err
