import moment from 'moment'
import yargs from 'yargs'
import {hideBin} from 'yargs/helpers'
import {inspect} from 'util'

# e.g. [--test] '["ETH", "USDT"]' 2024-04-01T00:00:00 2024-04-01T23:59:59 1d'
parse = -> ((yargs hideBin process.argv)
  .usage '$0 [--test] <pair> <start> [end] [freq]', 'meanVolUp', (yargs) ->
  .option 'test',
    alias: 't'
    describe: 'enable backtest'
    default: false
  .boolean ['test']
  .default 'end', moment().format()
  .default 'freq', '1'
  .parse()
)

export default parse
