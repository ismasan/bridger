# frozen_string_literal: true

require "parametric/dsl"

module Bridger
  class Action
    include Parametric::DSL

    def self.payload_schema(*args, &block)
      self.schema *args, &block
    end

    def self.query_schema(*args, &block)
      self.schema *(args.unshift(:query)), &block
    end

    def self.call(result)
      new(result).run!
    end

    attr_reader :query, :payload

    def initialize(result)
      @result = result
      @auth = result.auth
      @query = result.query
      @payload = result.payload
    end

    def run!
      result.continue run
    end

    private

    attr_reader :result, :auth

    def run
      raise NotImplementedError
    end
  end
end
