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

    def initialize(result)
      @result = result
      @validations = Pipeline.new do |pl|
        pl.query_schema self.class.query_schema
        pl.payload_schema self.class.payload_schema
      end
    end

    def run!
      @result = validations.call(result)
      result.halted? ? on_invalid(result) : run(result)
    end

    private

    attr_reader :result, :validations

    def auth
      @result.auth
    end

    def payload
      @result.payload
    end

    def query
      @result.query
    end

    def run(result)
      result
    end

    def on_invalid(result)
      result
    end
  end
end
