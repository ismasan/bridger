# frozen_string_literal: true

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

    def initialize(&config)
      @pipe = NOOP

      configure(&config) if block_given?
      freeze
    end

    def step(callable = nil, &block)
      callable ||= block
      raise ArgumentError, "#step expects an interface #call(Result) Result, but got #{callable.inspect}" unless is_a_step?(callable)

      @pipe = Bind.new(@pipe, callable)
      self
    end

    def step!(callable = nil, &block)
      callable ||= block
      raise ArgumentError, "#step expects an interface #call(Result) Result, but got #{callable.inspect}" unless is_a_step?(callable)

      @pipe = BindAny.new(@pipe, callable)
      self
    end

    def halt(&block)
      step do |result|
        result.halt(&block)
      end
    end

    def continue(&block)
      step do |result|
        result.continue(&block)
      end
    end

    def pipeline(&block)
      step self.class.new(&block)
    end

    def call(result)
      @pipe.call(result)
    end

    private

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
  end
end
