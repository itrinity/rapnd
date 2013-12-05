require 'logger'

module Rapnd
  class Log
    def initialize(options = {})
    end

    def write
      @logger ||= set_logger
    end

    def set_logger
      @logger = Logger.new(@logfile) if logfile
    end

    def logfile
      @logfile = Rapnd.config.logfile
    end
  end
end