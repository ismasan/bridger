# frozen_string_literal: true

require 'rack'

module Bridger
  class Result
    attr_reader :request, :response, :object, :query, :payload, :context, :errors, :auth

    # @param request [Rack::Request]
    # @param response [Rack::Response]
    # @option query [Hash]
    # @option payload [Hash, nil]
    # @option context [Hash]
    # @option auth [Bridger::Auth]
    # @option errors [Hash]
    def initialize(request, response, object: nil, query: {}, payload: nil, context: {}, auth: nil, errors: {})
      @request = request
      @response = response
      @object = object
      @query = query
      @payload = payload
      @context = context
      @auth = auth
      @errors = errors
    end

    def halted?
      false
    end

    def dup
      self.class.new(
        request,
        response.dup,
        object:,
        query: query.dup,
        payload: payload.dup,
        context: context.dup,
        auth: auth,
        errors: errors.dup,
      )
    end

    # @return [Boolean]
    def valid?
      errors.empty?
    end

    def [](key)
      context[key]
    end

    def []=(key, value)
      context[key] = value
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

    Undefined = Object.new.freeze

    private def copy_with(klass, object: Undefined, query: nil, payload: nil, context: nil, auth: nil, errors: nil, status: nil, &block)
      object = object == Undefined ? self.object : object
      query ||= self.query.dup
      payload ||= self.payload.dup
      context ||= self.context.dup
      auth ||= self.auth
      errors ||= self.errors.dup

      result = klass.new(request.dup, response.dup, object:, query:, payload:, context:, auth:, errors:)
      result.response.status = status if status

      if block_given?
        yield result
      end
      result
    end

    class Success < self
      def self.build(request: nil, response: nil, object: nil, query: {}, payload: {}, context: {})
        request ||= ::Rack::Request.new(::Rack::MockRequest.env_for('/'))
        response ||= ::Rack::Response.new(nil, 200, {})
        new(request, response, object:, query:, payload:, context:)
      end
    end

    class Halt < self
      def halted?; true; end
    end
  end
end
