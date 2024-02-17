Binance = require('../index').default

do ->
  try 
    broker = await new Binance()

    [..., side, symbol, quantity, price] = process.argv
    opts =
      symbol: symbol
      side: side
      type: 'LIMIT'
      timeInForce: 'GTC'
      quantity: quantity
      price: price
      timestamp: Date.now()
    console.log JSON.stringify (await broker.accounts()[0].placeOrder opts), null, 2
  catch err
    console.error err
