_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {combineLatest, from, concatMap, fromEvent, tap, map, filter} from 'rxjs'

if process.argv.length != 2
  console.log 'node -r coffeescript/register -r esm test/interval'
  process.exit 1

interval = ({broker, market, code, freq}) ->
  opts = {
    market
    code
    freq
    start: moment().subtract minute: 60 * parseInt freq
  }
  (await broker.dataKL opts)
    .pipe filter (i) ->
      market == i.market and code == i.code and freq == i.freq
    .pipe skipDup 'timestamp'
    .pipe strategy.indicator()
    .pipe strategy.meanInversion()
    .pipe filter (i) ->
      'entryExit' of i

watch = ({broker, market, code}) ->
  account = await broker.defaultAcc()
  m5 = await interval {broker, market, code, freq: '5'}
  m15 = await interval {broker, market, code, freq: '15'}
  combinaLatest [m5, m15]
    .pipe tap console.log
    .pipe filter (i) ->
      # filter m5 and m15 fall within range
      ret = moment
        .unix i[0]
        .diff i[1], 'minute'
      if not ret < 15
        console.log 
          m5: new Date i[0].timestamp
          m15: new Date i[1].timestamp
      ret < 15
    .pipe map (i) ->
      i[0].date = new Datei[0].timestamp
      i[0]
   .pipe filter (i) ->
      # filter those history data
      moment()
        .subtract minute: 2 * 5
        .isBefore moment.unix i.timestamp
    .pipe concatMap (i) ->
      from do -> await account.position()
        .pipe map (pos) ->
          {i, pos}
    .pipe concatMap ({i, pos}) ->
      from do -> await broker.quickQuote {market, code}
        .pipe map (quote) ->
          {i, pos, quote}
    .pipe filter ({i, pos, quote}) ->
      {ETH, USDT} = pos
      ETH ?= 0
      USDT ?= 0
      {buy, sell} = quote
      total = ETH * buy + USDT
      share = total / 3
      price = quote[i.entryExit.side]
      ret = (i.entryExit.side == 'buy' and USDT > share) or (i.entryExit.side == 'sell' and ETH * price > share)
      if not ret
        console.log "#{pos} #{ret}"
      ret
    .pipe tap console.log
    .subscribe ({i, pos, quote}) ->
      {ETH, USDT} = pos
      ETH ?= 0
      USDT ?= 0
      {buy, sell} = quote
      total = ETH * buy + USDT
      share = total / 3
      price = quote[i.entryExit.side]
      params =
        code: opts.code
        side: i.entryExit.side
        type: 'limit'
        price: price
        qty: Math.floor(share * 1000 / price) / 1000
      console.log params
      try
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
