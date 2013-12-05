require 'openssl'
require 'socket'

module Rapnd
  class Client
    def initialize(options = {})
      @cert = options[:cert]
      @password = options[:password]
      @host = options[:host]
    end

    def connect!
      Rapnd.logger.info 'Connecting...'

      cert = self.setup_certificate
      @socket = self.setup_socket(cert)

      Rapnd.logger.info 'Connected!'

      @socket
    end

    def setup_certificate
      Rapnd.logger.info 'Setting up certificate...'
      @context      = OpenSSL::SSL::SSLContext.new
      @context.cert = OpenSSL::X509::Certificate.new(File.read(@cert))
      @context.key  = OpenSSL::PKey::RSA.new(File.read(@cert), @password)
      Rapnd.logger.info 'Certificate created!'

      @context
    end

    def setup_socket(ctx)
      Rapnd.logger.info 'Connecting...'

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
        Rapnd.logger.info "Sending #{notification.device_token}: #{notification.json_payload}"
        socket.write(notification.to_bytes)
        socket.flush

        if IO.select([socket], nil, nil, 1) && error = socket.read(6)
          error = error.unpack('ccN')
          Rapnd.logger.error "Encountered error in push method: #{error}, backtrace #{error.backtrace}"
          return false
        end

        Rapnd.logger.info 'Message sent'

        true
      rescue OpenSSL::SSL::SSLError, Errno::EPIPE => e
        Rapnd.logger.error "Encountered error: #{e}, backtrace #{e.backtrace}"
        Rapnd.logger.info 'Trying to reconnect...'
        reset_socket
        Rapnd.logger.info 'Reconnected'
      end
    end
  end
end