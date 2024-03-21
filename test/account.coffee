Binance = require('../index').default

do ->
  try 
    broker = await new Binance()
    account = await broker.defaultAcc()
    {ETH, USDT} = await account.position()
    {buy, sell} = await broker.quickQuote code: 'ETHUSDT'
    console.log JSON.stringify {ETH, USDT}
    console.log JSON.stringify {buy, sell}
    console.log USDT: ETH * buy + USDT
###
    (await account.historyOrder()) 
      .subscribe console.log
    console.log JSON.stringify (await broker.client.getExchangeInfo symbol: 'ETHUSDT'), null, 2
    price = parseFloat process.argv[2]
    await account.enableOrder await account.placeOrder
      code: 'ETHUSDT'
      side: 'buy'
      type: 'limit'
      price: price 
      qty: Math.floor(position.USDT * 10000 / price) / 10000
###
  catch err
    console.error err
