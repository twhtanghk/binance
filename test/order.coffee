_ = require 'lodash'
moment = require 'moment'
Binance = require('../index').default
import {map} from 'rxjs'

do ->
  try 
    broker = await new Binance()

    code = 'ETHUSDT'
    beginTime = moment().subtract month: 1
    endTime = moment()
    i = 0
    (await (await broker.defaultAcc()).historyOrder {code, beginTime, endTime})
      .pipe map (x) ->
        _.extend x, date: (moment x.time).format()
      .subscribe (x) ->
        console.log ++i
        console.log x
###
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
###
  catch err
    console.error err
