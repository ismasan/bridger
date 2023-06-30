# frozen_string_literal: true

require 'bridger/result'
require 'bridger/pipeline/schema_steps'

module Bridger
  class Pipeline
    NOOP = -> (result) { result }

    # The Bind function.
    # Only forward result from left to right callable if result is not halted.
    class Bind
      # @param left [Step]
      # @param right [Step]
      def initialize(left, right)
        @left = left
        @right = right
      end

      def inspect
        %(Bind(#{@left.inspect}, #{@right.inspect}))
      end

      # @param result [Result]
      # @return [Result]
      def call(result)
        result = @left.call(result)
        result.halted? ? result : @right.call(result)
      end
    end

    # The BindAny function.
    # Forward result from left to right callable regardless of result being halted.
    class BindAny
      # @param left [Step]
      # @param right [Step]
      def initialize(left, right)
        @left = left
        @right = right
      end

      # @param result [Result]
      # @return [Result]
      def call(result)
        @right.call(@left.call(result))
      end
    end

    NOOP_SCHEMA = Parametric::Schema.new

    def initialize(instrumenter: Bridger::NullInstrumenter, &config)
      @instrumenter = instrumenter
      @pipe = NOOP
      @query_schema = NOOP_SCHEMA
      @payload_schema = NOOP_SCHEMA

      configure(&config) if block_given?
      freeze
    end

    def to_s
      %(#<#{self.class.name}>)
    end

    def instrument(*args, &block)
      case args
      in [callable, String => label, Hash => opts] # instrument(step, 'foo', identifier: 'foo')
        step do |result|
          instrumenter.instrument(label, opts) { callable.call(result) }
        end
      in [callable, String => label] # instrument(step, 'foo')
        step do |result|
          instrumenter.instrument(label) { callable.call(result) }
        end
      in [String => label, Hash => opts] if block_given? # instrument('foo', identifier: 'foo', &block)
        callable = Pipeline.new(instrumenter:, &block)
        step do |result|
          instrumenter.instrument(label, opts) { callable.call(result) }
        end
      in [String => label] if block_given? # instrument('foo', &block)
        callable = Pipeline.new(instrumenter:, &block)
        step do |result|
          instrumenter.instrument(label) { callable.call(result) }
        end
      else
        raise ArgumentError, "instrument expects a step or a block, but got #{args.inspect}"
      end
    end

    def step(callable = nil, &block)
      register_step(Bind, callable:, &block)
    end

    def step!(callable = nil, &block)
      register_step(BindAny, callable:, &block)
    end

    def halt(&block)
      step do |result|
        result.halt(&block)
      end
    end

    def continue(&block)
      step! do |result|
        result.continue(&block)
      end
    end

    def pipeline(&block)
      step self.class.new(&block)
    end

    def query_schema(schema = nil, &block)
      return @query_schema unless schema || block_given?

      step SchemaSteps::Query.new(schema, &block)
    end

    def payload_schema(schema = nil, &block)
      return @payload_schema unless schema || block_given?

      step SchemaSteps::Payload.new(schema, &block)
    end

    # The Step interface
    #
    # @param result [Bridger::Result]
    # @return [Bridger::Result]
    def call(result)
      @pipe.call(result)
    end

    private

    attr_reader :instrumenter

    def register_step(bind_class, callable: nil, &block)
      callable ||= block
      callable = callable.to_pipeline_step if callable.respond_to?(:to_pipeline_step)
      raise ArgumentError, "#step expects an interface #call(Result) Result, but got #{callable.inspect}" unless is_a_step?(callable)

      merge_query_schema(callable.query_schema) if callable.respond_to?(:query_schema)
      merge_payload_schema(callable.payload_schema) if callable.respond_to?(:payload_schema)

      @pipe = bind_class.new(@pipe, callable)
      self
    end

    def configure(&setup)
      case setup.arity
      when 1
        setup.call(self)
      when 0
        instance_eval(&setup)
      else
        raise ArgumentError, 'setup block must have arity of 0 or 1'
      end
    end

    def is_a_step?(callable)
      return false unless callable.respond_to?(:call)

      arity = callable.respond_to?(:arity) ? callable.arity : callable.method(:call).arity
      arity == 1
    end

    def merge_query_schema(schema)
      @query_schema = @query_schema.merge(schema)
    end

    def merge_payload_schema(schema)
      @payload_schema = @payload_schema.merge(schema)
    end
  end
end
