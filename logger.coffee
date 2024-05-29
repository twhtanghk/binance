{inspect} = require 'util'
{createLogger, format, transports} = require 'winston'
{combine, simple, timestamp} = format

export logger = createLogger
  level: process.env.LEVEL || 'info'
  format: combine timestamp(), simple()
  transports: [ new transports.Console() ]

export default logger
