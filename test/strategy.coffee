_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
strategy = require('algotrader/rxStrategy').default
{skipDup} = require('algotrader/analysis').default.ohlc
import {tap, map, filter} from 'rxjs'

enable = false
process.on 'SIGUSR1', ->
  enable = !enable
  console.log "enable = #{enable}"

if process.argv.length != 3
  console.log 'node -r coffeescript/register -r esm test/strategy meanReversion'
  process.exit 1

do ->
  try 
    [..., selectedStrategy] = process.argv
    market = 'crypto'
    code = 'ETHUSDT'
    freq = '5'
    broker = await new Binance()
    account = await broker.defaultAcc()
    opts =
      market: market
      code: code
      start: moment().subtract minute: 60 * parseInt freq
      freq: freq
    (await broker.dataKL opts)
      .pipe filter (i) ->
        market == i.market and code == i.code and freq == i.freq
      .pipe skipDup 'timestamp'
      .pipe map (i) ->
        i.date = new Date i.timestamp * 1000
        i
      .pipe strategy.indicator()
      .pipe strategy[selectedStrategy]()
      .pipe strategy.volUp() 
      .pipe filter (i) ->
        'entryExit' of i
      .pipe tap console.log
      .pipe filter ->
        enable
      .pipe filter ({entryExit}) ->
        entryExit[0]?.strategy == 'meanReversion'
      .pipe filter ({entryExit}) ->
        entryExit[1]?.strategy == 'volUp'
      .pipe filter (i) ->
        # close price change sharply or remain in flat
        i['close.stdev'] > i['close'] * 0.4 / 100 or
        i['close.stdev'] < i['close'] * 0.12 / 100 
      .subscribe (i) ->
        meanReversion = _.find i.entryExit, strategy: 'meanReversion'
        volUp = _.find i.entryExit, strategy: 'volUp'
        position = await account.position()
        {open, close} = i
        price = (await broker.quickQuote({market, code}))[meanReversion.side]
        params =
          code: opts.code
          side: meanReversion.side
          type: 'limit'
          price: price
        try
          if meanReversion?.side == 'buy' and volUp?.side and position.USDT? and position.USDT > 10
            params.qty = Math.floor(position.USDT * 1000 / price) / 1000
            console.log params
            index = await account.placeOrder params
            await account.enableOrder index
          if meanReversion?.side == 'sell' and volUp?.side and position.ETH? and position.ETH > 0.01
            params.qty = Math.floor(position.ETH * 1000) / 1000
            console.log params
            index = await account.placeOrder params
            await account.enableOrder index
        catch err
          console.error err
  catch err
    console.error err
