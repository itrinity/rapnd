require 'redis'
require 'active_support/ordered_hash'
require 'active_support/json'
require 'base64'
require 'airbrake'
require 'rapnd/client'
require 'rapnd/config'
require 'rapnd/log'

module Rapnd
  class Daemon
    attr_accessor :redis, :host, :apple, :cert, :queue, :connected, :logger, :airbrake
    
    def initialize(options = {})
      options[:redis_host]  ||= 'localhost'
      options[:redis_port]  ||= '6379'
      options[:host]        ||= 'gateway.sandbox.push.apple.com'
      options[:port]        ||=  2195
      options[:queue]       ||= 'rapnd_queue'
      options[:password]    ||= ''
      raise 'No cert provided!' unless options[:cert]
      
      #Airbrake.configure { |config| config.api_key = options[:airbrake]; @airbrake = true; } if options[:airbrake]
      
      redis_options = { :host => options[:redis_host], :port => options[:redis_port] }
      redis_options[:password] = options[:redis_password] if options.has_key?(:redis_password)
      
      @redis = Redis.new(redis_options)
      @queue = options[:queue]
      @cert = options[:cert]
      @password = options[:password]
      @host = options[:host]
      @port = options[:port]
      @dir = options[:dir]
      #@logger ||= Logger.new("#{options[:dir]}/log/#{options[:queue]}.log")

      Rapnd.configure do |config|
        config.logfile = options[:logfile]
      end

      @logger = Rapnd::Log.new.write
      @logger.info "Listening on queue: #{self.queue}"
    end
    
    def run!
      loop do
        begin
          message = @redis.blpop(self.queue, 1)
          if message
            notification = Rapnd::Notification.new(JSON.parse(message.last,:symbolize_names => true))

            client.push(notification)
          end
        rescue Exception => e
          if e.class == Interrupt || e.class == SystemExit
            @logger.info 'Shutting down...'
            exit(0)
          end

          @logger.error "Encountered error: #{e}, backtrace #{e.backtrace}"

          @logger.info 'Trying to reconnect...'
          client.connect!
          @logger.info 'Reconnected'

          client.push(notification)
        end
      end
    end

    def client
      @client ||= Rapnd::Client.new(host: @host, port: @port, cert: @cert, password: @password, dir: @dir, queue: @queue)
    end
  end
end