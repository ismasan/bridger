# frozen_string_literal: true

require 'rack'

module Bridger
  class Result
    attr_reader :request, :response, :query, :payload, :context, :errors

    # @param request [Rack::Request]
    # @param response [Rack::Response]
    # @param query [Hash]
    # @param payload [Hash, nil]
    # @param context [Hash]
    # @param errors [Hash]
    def initialize(request, response, query: {}, payload: nil, context: {}, errors: {})
      @request = request
      @response = response
      @query = query
      @payload = payload
      @context = context
      @errors = errors
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
        errors: errors.dup,
      )
    end

    # @return [Boolean]
    def valid?
      errors.empty?
    end

    def copy(**kargs, &block)
      copy_with(self.class, **kargs, &block)
    end

    def continue(**kargs, &block)
      copy_with(Success, **kargs, &block)
    end

    def halt(**kargs, &block)
      copy_with(Halt, **kargs, &block)
    end

    private def copy_with(klass, query: nil, payload: nil, context: nil, errors: nil, &block)
      query ||= self.query.dup
      payload ||= self.payload.dup
      context ||= self.context.dup
      errors ||= self.errors.dup

      result = klass.new(request.dup, response.dup, query:, payload:, context:, errors:)
      if block_given?
        yield result
      end
      result
    end

    class Success < self
      def self.build(request: nil, response: nil, query: {}, payload: {})
        request ||= ::Rack::Request.new(::Rack::MockRequest.env_for('/'))
        response ||= ::Rack::Response.new(nil, 200, {})
        new(request, response, query:, payload:)
      end
    end

    class Halt < self
      def halted?; true; end
    end
  end
end
