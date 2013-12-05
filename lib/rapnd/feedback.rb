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
      options[:host] ||= 'feedback.push.apple.com'
      options[:port] ||= 2196
    end
  end
end