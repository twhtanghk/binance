moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {tap, map, filter} from 'rxjs'

if process.argv.length != 3
  console.log 'node -r coffeescript/register -r esm test/strategy meanReversion'
  process.exit 1

do ->
  try 
    broker = await new Binance()
    account = await broker.defaultAcc()
    opts =
      market: 'crypto'
      code: 'ETHUSDT'
      start: moment().subtract minute: 60 * 5
      freq: '5'
    (await broker.dataKL opts)
      .pipe filter ({market, code, freq}) ->
        market == opts.market and code == opts.code and freq == opts.freq
      .pipe skipDup 'timestamp'
      .pipe strategy.indicator()
      .pipe strategy[process.argv[2]]()
      .pipe tap console.log
      .subscribe (i) ->
        if 'entryExit' of i
          position = await account.position()
          {high, low} = i
          price = (high + low) / 2
          opts =
            code: opts.code
            side: i.entryExit.side
            price: price
          if i.entryExit.side == 'buy' and position.USDT != 0
            opts.qty = position.USDT / price
          if i.entryExit.side == 'sell' and position.ETH != 0
            opts.qty = position.ETH
          await account.placeOrder opts
    (await account.orders())
      .subscribe console.log
  catch err
    console.error err
