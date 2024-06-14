import Binance from '../index.js'
logger = require('../logger').default

do ->
  try
    broker = new Binance()
    account = await broker.defaultAcc()
    logger.info await account.openOrders()
  catch err
    logger.error err
