# frozen_string_literal: true

require 'rack'

module Bridger
  class RackHandler
    DEFAULT_HEADERS = { 'Content-Type' => 'application/json' }.freeze

    def initialize(service, endpoint)
      @service = service
      @endpoint = endpoint
    end

    def call(env)
      request = ::Rack::Request.new(env)
      response = ::Rack::Response.new(nil, 200, DEFAULT_HEADERS)
      initial = Bridger::Result::Success.new(request, response)
      result = @endpoint.call(initial)
      result.response.finish
    end
  end
end
