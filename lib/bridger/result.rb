# frozen_string_literal: true

require 'rack'

module Bridger
  class Result
    attr_reader :request, :response, :query, :payload, :data, :errors, :auth

    # @param request [Rack::Request]
    # @param response [Rack::Response]
    # @option query [Hash]
    # @option payload [Hash, nil]
    # @option data [Hash]
    # @option auth [Bridger::Auth]
    # @option errors [Hash]
    def initialize(request, response, query: {}, payload: nil, data: {}, auth: nil, errors: {})
      @request = request
      @response = response
      @query = query
      @payload = payload
      @data = data
      @auth = auth
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
        data: data.dup,
        auth: auth,
        errors: errors.dup,
      )
    end

    # @return [Boolean]
    def valid?
      errors.empty?
    end

    def [](key)
      data.fetch(key)
    end

    def []=(key, value)
      data[key] = value
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

    private def copy_with(klass, query: nil, payload: nil, data: nil, auth: nil, errors: nil, &block)
      query ||= self.query.dup
      payload ||= self.payload.dup
      data ||= self.data.dup
      auth ||= self.auth
      errors ||= self.errors.dup

      result = klass.new(request.dup, response.dup, query:, payload:, data:, auth:, errors:)
      if block_given?
        yield result
      end
      result
    end

    class Success < self
      def self.build(request: nil, response: nil, query: {}, payload: {}, data: {})
        request ||= ::Rack::Request.new(::Rack::MockRequest.env_for('/'))
        response ||= ::Rack::Response.new(nil, 200, {})
        new(request, response, query:, payload:, data:)
      end
    end

    class Halt < self
      def halted?; true; end
    end
  end
end
