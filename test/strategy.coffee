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
      .pipe filter (i) ->
        'entryExit' of i
      .pipe tap console.log
      .subscribe (i) ->
        position = await account.position()
        {high, low} = i
        price = (high + low) / 2
        opts =
          code: opts.code
          side: i.entryExit.side
          type: 'limit'
          price: price
        try
          if i.entryExit.side == 'buy' and position.USDT? and position.USDT != 0
            opts.qty = position.USDT / price
            console.log opts
            index = await account.placeOrder opts
            await account.enableOrder index
          if i.entryExit.side == 'sell' and position.ETH? and position.ETH != 0
            opts.qty = position.ETH
            console.log opts
            index = await account.placeOrder opts
            await account.enableOrder index
        catch err
          console.error err
    (await account.orders())
      .subscribe console.log
  catch err
    console.error err
