_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {tap, map, filter} from 'rxjs'

enable = false
process.on 'SIGTERM', ->
  enable = !enable
  console.log "enable = #{enable}"

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
      .pipe map (i) ->
        i.date = new Date i.timestamp * 1000
        i
      .pipe strategy.indicator()
      .pipe strategy[process.argv[2]]()
      .pipe filter (i) ->
        'entryExit' of i
      .pipe filter ->
        enable
      .pipe filter (i) ->
        i['close.stdev'] > i['close'] * 0.4 / 100
      .pipe tap console.log
      .subscribe (i) ->
        position = await account.position()
        {open, close} = i
        price = Math.floor((open + close) * 100 / 2) / 100
        params =
          code: opts.code
          side: i.entryExit.side
          type: 'limit'
          price: price
        try
          if i.entryExit.side == 'buy' and position.USDT? and position.USDT > 10
            params.qty = Math.floor(position.USDT * 1000 / price) / 1000
            console.log params
            index = await account.placeOrder params
            await account.enableOrder index
          if i.entryExit.side == 'sell' and position.ETH? and position.ETH > 0.01
            params.qty = Math.floor(position.ETH * 1000) / 1000
            console.log params
            index = await account.placeOrder params
            await account.enableOrder index
        catch err
          console.error err
    (await account.orders())
      .subscribe console.log
  catch err
    console.error err
