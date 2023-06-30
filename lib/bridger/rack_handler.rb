# frozen_string_literal: true

require 'rack'

module Bridger
  class RackHandler
    DEFAULT_HEADERS = { 'Content-Type' => 'application/json' }.freeze

    def initialize(endpoint)
      @endpoint = endpoint
    end

    def call(env)
      request = env.is_a?(::Hash) ? ::Rack::Request.new(env) : env
      response = ::Rack::Response.new(nil, 200, DEFAULT_HEADERS)
      initial = Bridger::Result::Success.new(request, response)
      result = @endpoint.call(initial)
      result.response.finish
    end
  end
end
