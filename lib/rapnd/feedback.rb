module Rapnd
  class FeedbackItem
    attr_accessor :timestamp, :token

    def initialize(time, token)
      @timestamp = time
      @token = token
    end
  end

  class Feedback
    def initialize(options = {})
      options[:host]        ||= 'feedback.push.apple.com'
      options[:port]        ||= 2196
      options[:password]    ||= ''

      @cert = options[:cert]
      @password = options[:password]
      @host = options[:host]
      @port = options[:port]
    end

    def data
      @feedback ||= receive
    end

    def receive
      feedbacks = []
      while f = client.feedback
        feedbacks << f
      end
      return feedbacks
    end

    def client
      @client ||= Rapnd::Client.new(host: @host, port: @port, cert: Rapnd.config.cert_file, password: Rapnd.config.cert_password)
    end
  end
end