require 'redis'
require 'openssl'
require 'socket'
require 'active_support/ordered_hash'
require 'active_support/json'
require 'base64'
require 'airbrake'
require 'logger'

module Rapnd
  class Daemon
    attr_accessor :redis, :host, :apple, :cert, :queue, :connected, :logger, :airbrake
    
    def initialize(options = {})
      options[:redis_host]  ||= 'localhost'
      options[:redis_port]  ||= '6379'
      options[:host]        ||= 'gateway.sandbox.push.apple.com'
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
      @logger = Logger.new("#{options[:dir]}/log/#{options[:queue]}.log")
      @logger.info "Listening on queue: #{self.queue}"
    end
    
    def connect!
      @logger.info 'Connecting...'

      cert = self.setup_certificate
      @socket = self.setup_socket(cert)

      @logger.info 'Connected!'

      @socket
    end

    def setup_certificate
      @logger.info 'Setting up certificate...'
      @context      = OpenSSL::SSL::SSLContext.new
      @context.cert = OpenSSL::X509::Certificate.new(File.read(@cert))
      @context.key  = OpenSSL::PKey::RSA.new(File.read(@cert), @password)
      @logger.info 'Certificate created!'

      @context
    end

    def setup_socket(ctx)
      @logger.info 'Connecting...'

      socket_tcp = TCPSocket.new(@host, 2195)
      OpenSSL::SSL::SSLSocket.new(socket_tcp, ctx).tap do |s|
        s.sync = true
        s.connect
      end
    end

    def reset_socket
      @socket.close if @socket
      @socket = nil

      connect!
    end

    def socket
      @socket ||= connect!
    end

    def push(notification)
      begin
        @logger.info "Sending #{notification.device_token}: #{notification.json_payload}"
        socket.write(notification.to_bytes)
        socket.flush
        @logger.info 'Message sent'

        true
      rescue OpenSSL::SSL::SSLError, Errno::EPIPE => e
        @logger.error "Encountered error: #{e}, backtrace #{e.backtrace}"
        @logger.info 'Trying to reconnect...'
        reset_socket
        @logger.info 'Reconnected'
      end
    end
    
    def run!
      loop do
        begin
          message = @redis.blpop(self.queue, 1)
          if message
            notification = Rapnd::Notification.new(JSON.parse(message.last,:symbolize_names => true))

            self.push(notification)
          end
        rescue Exception => e
          if e.class == Interrupt || e.class == SystemExit
            @logger.info 'Shutting down...'
            exit(0)
          end

          @logger.error "Encountered error: #{e}, backtrace #{e.backtrace}"

          @logger.info 'Trying to reconnect...'
          self.connect!
          @logger.info 'Reconnected'

          retry
        end
      end
    end
  end
end