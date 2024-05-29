{freqDuration} = require('algotrader/rxData').default
import {extend, defaults} from 'lodash'
import moment from 'moment'
import yargs from 'yargs'
import {hideBin} from 'yargs/helpers'

ohlc =
  pair: ['ETH', 'USDT']
  start: null
  end: null
  freq: '1'

order =
  nShare: 7

# e.g. [--test] '["ETH", "USDT"]' 2024-04-01T00:00:00 2024-04-01T23:59:59 1d'
parse = -> 
  ret = (yargs hideBin process.argv)
    .usage '$0 [--test] [--ohlc opts] [--order opts]', '$0', (yargs) ->
    .option 'test',
      type: 'boolean'
      describe: 'enable backtest'
      default: false
    .option 'ohlc',
      type: 'string'
      describe: 'ohlc opts'
      default: JSON.stringify ohlc
    .option 'order',
      type: 'string'
      describe: 'order opts'
      default: JSON.stringify order
    .parse()
  ret.ohlc = defaults (JSON.parse ret.ohlc), ohlc
  if typeof ret.ohlc.start == 'string' 
    ret.ohlc.start = moment ret.ohlc.start
  # force start time to be (now - 20 * freq) for real order
  if not ret.test
    minute = 20 * moment
      .duration freqDuration[ret.ohlc.freq].duration
      .asMinutes()
    ret.ohlc.start = moment().subtract {minute}
  if typeof ret.ohlc.end == 'string'
    ret.ohlc.end = moment ret.ohlc.end
  # force end time to be now for backtest
  if ret.test and ret.ohlc.end == null
    ret.ohlc.end = moment()
  ret.order = defaults (JSON.parse ret.order), order
  ret
  
export default parse
