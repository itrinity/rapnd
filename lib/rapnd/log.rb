require 'logger'

module Rapnd
  class Log
    def initialize(options = {})
      options[:logfile] ||= nil

      @logfile = options[:logfile]
    end

    def write
      @logger ||= set_logger
    end

    def set_logger
      @logger = Logger.new(@logfile) if @logfile
    end
  end
end