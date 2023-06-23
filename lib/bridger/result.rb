# frozen_string_literal: true

module Bridger
  class Result
    attr_reader :request, :response, :query, :payload, :context

    # @param request [Rack::Request]
    # @param response [Rack::Response]
    # @param query [Hash]
    # @param payload [Hash, nil]
    # @param context [Hash]
    def initialize(request, response, query: {}, payload: nil, context: {})
      @request = request
      @response = response
      @query = query
      @payload = payload
      @context = context
    end

    def halted?
      false
    end

    def dup
      self.class.new(
        request.dup,
        response.dup,
        query: query.dup,
        payload: payload.dup,
        context: context.dup,
      )
    end

    class Success < self
      def continue(&block)
        return self unless block_given?

        result = dup
        yield result
        result
      end

      def halt(&block)
        result = self
        if block_given?
          result = dup
          yield result
        end

        Halt.new(
          result.request,
          result.response,
          query: result.query,
          payload: result.payload,
          context: result.context,
        )
      end
    end

    class Halt < self
      def halted?; true; end

      def halt(&block)
        return self unless block_given?

        result = dup
        yield result
        result
      end

      def continue(&block)
        result = self
        if block_given?
          result = dup
          yield result
        end

        Success.new(
          result.request,
          result.response,
          query: result.query,
          payload: result.payload,
          context: result.context,
        )
      end
    end
  end
end
