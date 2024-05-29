{inspect} = require 'util'
{createLogger, format, transports} = require 'winston'
{combine, simple, timestamp} = format
custom = format (info, opts) ->
  info.message = inspect info.message, depth: 4
  info

export logger = createLogger
  level: process.env.LEVEL || 'info'
  format: combine timestamp(), custom(), simple()
  transports: [ new transports.Console() ]

export default logger
