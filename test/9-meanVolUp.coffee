_ = require 'lodash'
moment = require 'moment'
{find, indicator, meanReversion} = require('algotrader/rxStrategy').default 
{skipDup} = require('algotrader/analysis').default.ohlc
Binance = require('../index').default
{createLogger} = winston = require 'winston'
import {concatMap, from, combineLatest, bufferCount, map, filter, tap} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: winston.format.simple()
  transports: [ new winston.transports.Console() ]

do ->
  try
    broker = await new Binance()
    code = 'ETHUSDT'
    account = await broker.defaultAcc()
    nShare = 5

    ohlc = (await broker.dataKL {code: code, start: moment().subtract(minute: 20), freq: '1'})
      .pipe skipDup 'timestamp'
      .pipe map (x) ->
        _.extend x, date: moment.unix x.timestamp

    mean = ohlc
      .pipe indicator()
      .pipe meanReversion()
      .pipe map (x) ->
        if x['close'] > x['close.mean'] + 2 * x['close.stdev']
          x.entryExit ?= []
          x.entryExit.push {id: 'mean', side: 'sell', price: x['close']}
        else if x['close'] < x['close.mean'] - 2 * x['close.stdev']
          x.entryExit ?= []
          x.entryExit.push {id: 'mean', side: 'buy', price: x['close']}
        x
      .pipe filter (x) ->
        ret = _.find x.entryExit, (i) -> i.id == 'mean'
        ret? 

    volUp = ohlc
      .pipe find.volUp() 
      .pipe filter (x) ->
        x['volume'] > x['volume.mean'] * 2

    (combineLatest [mean, volUp])
      .pipe filter ([m, v]) ->
        m.timestamp == v.timestamp
      .pipe concatMap ([m, v]) ->
        from do -> await account.position()
          .pipe map (pos) ->
            [m, v, pos]
      .pipe filter ([m, v, pos]) ->
        {ETH, USDT} = pos
        ETH ?= 0
        USDT ?= 0
        total = ETH * m['close'] + USDT
        share = total / nShare
        {side, price} = _.find m.entryExit, (x) -> x.id == 'mean'
        ret = (side == 'buy' and USDT > share) or (side == 'sell' and ETH * price > share)
        logger.info "total, share, ret: #{total}, #{share}, #{ret}"
        ret
      .subscribe ([m, v, pos]) ->
        {ETH, USDT} = pos
        ETH ?= 0
        USDT ?= 0
        total = ETH * m['close'] + USDT
        share = total / nShare
        {side, price} = _.find m.entryExit, (x) -> x.id == 'mean'
        params =
          code: code
          side: side
          type: 'limit'
          price: price
          qty: Math.floor(share * 1000 / price) / 1000
        logger.info JSON.stringify params
        try
          index = await account.placeOrder params
          await account.enableOrder index
        catch err
          logger.error err
  catch err
    logger.error err
