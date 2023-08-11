# frozen_string_literal: true

require "parametric/dsl"

module Bridger
  # Action is a utility class to encapsulate a Pipeline while
  # still providing a class that can hold internal state.
  # Action classes can define #query_schema and #payload_schema
  # which will be validated as a first step before invoking #run(result).
  # It is meant to be subclassed.
  #
  # @example
  #
  #  class MyAction < Bridger::Action
  #    payload_schema do
  #      field(:age).type(:integer).default(40)
  #      field(:name).type(:string).present
  #    end
  #
  #    def run(result)
  #      # We have `#payload, #query, #auth` available here
  #      # which are the same as `result.payload, result.query, result.auth`
  #      result.continue("#{payload[:name]} is #{payload[:age]} years old")
  #    end
  #  end
  #
  # Action subclasses can override #pipeline to define a custom pipeline.
  #
  # @example
  #
  # class MyAction < Bridger::Action
  #   def pipeline
  #     Bridger::Pipeline.new do |pl|
  #       pl.step method(:before_schemas)
  #       pl.step validate_schemas # <- this is built-in
  #       pl.step method(:after_schemas)
  #       pl.step! method(:always_run)
  #     end
  #   end
  #
  #   def before_schemas(result)
  #     result.continue do |r|
  #       r[:before] = true
  #     end
  #   end
  #
  #   def after_schemas(result)
  #     result.continue do |r|
  #       r[:after] = true
  #     end
  #   end
  #
  #   def always_run(result)
  #     result.copy do |r|
  #       r[:always] = true
  #     end
  #   end
  # end
  class Action
    include Parametric::DSL

    def self.payload_schema(*args, &block)
      self.schema *args, &block
    end

    def self.query_schema(*args, &block)
      self.schema *(args.unshift(:query)), &block
    end

    # The [Step] interface is the same as [Pipeline] interface.
    # @param result [Bridger::Result]
    # @return [Bridger::Result]
    def self.call(result)
      new(result).run!
    end

    # @param result [Bridger::Result]
    def initialize(result)
      @result = result
      @validate_schemas = Pipeline.new do |pl|
        pl.query_schema self.class.query_schema
        pl.payload_schema self.class.payload_schema
        pl.step { |r| @result = r }
      end
      @pipeline = build_pipeline
    end

    # @return [Bridger::Result]
    def run!
      pipeline.call(result)
    end

    private

    attr_reader :result, :validate_schemas, :pipeline

    def build_pipeline
      Pipeline.new do |pl|
        pl.step validate_schemas
        pl.step method(:run)
      end
    end

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
  end
end
