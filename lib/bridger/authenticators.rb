# frozen_string_literal: true

module Bridger
  module Authenticators
    SPACE = /\s+/.freeze

    class RequestHeader
      def initialize(header_name)
        @header_name = header_name.to_s
      end

      def call(request)
        request.env[@header_name].to_s.split(SPACE).last
      end

      def to_s
        %(['#{@header_name}' in request headers])
      end
    end

    class RequestQuery
      def initialize(param_name)
        @param_name = param_name.to_s
      end

      def call(request)
        request.params[@param_name]
      end

      def to_s
        %(['#{@param_name}' in request query string])
      end
    end
  end
end
