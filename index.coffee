import moment from 'moment'
import {EventEmitter} from 'events'
import {readFile} from 'fs/promises'
import {MainClient} from 'binance'
{freqDuration} = require('algotrader/data').default

class Binance extends EventEmitter
  @api_key: process.env.BINANCE_API_KEY
  @rsa_key: do ->
    (await readFile '/tmp/binance/binance-private-key.pem').toString()
  @freqMap: (interval) ->
    map =
      '1': '1m'
      '5': '5m'
      '15': '15m'
      '30': '30m'
    return if interval of map then map[interval] else interval

  constructor: ->
    super()
    return do =>
      @client = new MainClient
        api_key: Binance.api_key
        api_secret: await Binance.rsa_key
        beautifyResponse: true
      @

  historyKL: ({code, interval, start, end} = {}) ->
    code ?= 'BTCUSDT'
    interval ?= '1'
    end ?= moment()
    start ?= moment end
      .subtract freqDuration[interval]
    await @client.getKlines 
      symbol: code
      interval: Binance.freqMap interval
      startTime: start.valueOf()
      endTime: end.valueOf()

export default Binance
