_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
{createLogger} = winston = require 'winston'
import {concatMap, from, map} from 'rxjs'

logger = createLogger
  level: process.env.LEVEL || 'info'
  format: winston.format.simple()
  transports: [ new winston.transports.Console() ]

do ->
  try 
    broker = await new Binance()

    code = 'ETHUSDT'
    beginTime = moment().startOf 'month'
    endTime = moment()
    ret = []
    account = await broker.defaultAcc()
    (await account.historyOrder {code, beginTime, endTime})
      .pipe map (x) ->
        _.extend x, date: (moment x.time).format()
      .pipe concatMap (x) ->
        from do -> await account.position()
          .pipe map (pos) ->
            {ETH, USDT} = pos
            pos = _.extend {}, 
              date: x.date
              side: x.side
              qty: x.executedQty
              price: x.price
              pos: pos
              sum: 
                ETH: USDT / x.price + ETH
                USDT: ETH * x.price + USDT 
            {x, pos}
      .subscribe 
        next: ({x, pos}) ->
          logger.debug JSON.stringify x
          ret.push pos
        complete: ->
          # view result by http://json2table.com/
          logger.info JSON.stringify ret
  catch err
    console.error err
