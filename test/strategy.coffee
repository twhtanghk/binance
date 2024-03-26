_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {fromEvent, tap, map, filter} from 'rxjs'

enable = false
process.on 'SIGUSR1', ->
  enable = !enable
  console.log "enable = #{enable}"

if process.argv.length != 3
  console.log 'node -r coffeescript/register -r esm test/strategy meanReversion'
  process.exit 1

watch = ({broker, market, code, freq, selectedStrategy}) ->
  opts =
    market: market
    code: code
    start: moment().subtract minute: 60 * parseInt freq
    freq: freq
  account = await broker.defaultAcc()
  (await broker.dataKL opts)
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
    .pipe skipDup 'timestamp'
    .pipe map (i) ->
      i.date = new Date i.timestamp * 1000
      i
    .pipe strategy.indicator()
    .pipe strategy[selectedStrategy]()
    .pipe filter (i) ->
      'entryExit' of i
    .pipe tap console.log
    .pipe filter ->
      enable
    .pipe filter (i) ->
      # close price change sharply or remain in flat
      i['close.stdev'] > i['close'] * 0.4 / 100 or
      i['close.stdev'] < i['close'] * 0.12 / 100 
    .pipe tap console.log
    .subscribe (i) ->
      {ETH, USDT} = await account.position()
      {open, close} = i
      {buy, sell} = await broker.quickQuote {market, code}
      total = ETH * buy + USDT
      share = total / 5
      price = {buy, sell}[i.entryExit.side]
      params =
        code: opts.code
        side: i.entryExit.side
        type: 'limit'
        price: price
        qty: Math.floor(share * 1000 / price) / 1000
      console.log params
      try
        if (i.entryExit.side == 'buy' and USDT > share) or (i.entryExit.side == 'sell' and ETH * price > share)
          index = await account.placeOrder params
          await account.enableOrder index
      catch err
        console.error err

do ->
  try 
    [..., selectedStrategy] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    freq = '5'
    broker = await new Binance()
    subscription = await watch {broker, market, code, freq, selectedStrategy}
    fromEvent broker.ws, 'reconnected'
      .subscribe ->
        subscription.unsubscribe()
        subscription = await watch {broker, market, code, freq, selectedStrategy}
  catch err
    console.error err
