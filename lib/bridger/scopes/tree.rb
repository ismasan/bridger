# frozen_string_literal: true

require 'bridger/scopes/scope'

module Bridger
  class Scopes
    # A utility to define and access allowed scope hierarchies.
    # Example:
    #
    #  SCOPES = Bridger::Scopes::Tree.new('bootic') do |bootic|
    #    bootic.api.products.own.read
    #    bootic.api.products.all.read
    #    bootic.api.orders.own.read
    #  end
    #
    #  SCOPES.bootic.api.products.own.read.to_s # => 'bootic.api.products.own.read'
    #  SCOPES.bootic.api.products.own.to_s # => 'bootic.api.products.own'
    #  SCOPES.bootic.api.*.read.to_s # => 'bootic.api.*.read'
    #  SCOPES.bootic.foo.products # => NoMethodError
    #
    # It can be used to define allowed scopes for an endpoint:
    #
    # Bridger::Endpoint.new(
    #  name: 'create_product',
    #  verb: :post,
    #  path: '/v1/products',
    #  ...
    #  scope: SCOPES.bootic.api.products.own,
    #  ...
    # )
    #
    # Hierarchies can also be defined using the > operator:
    # This can help avoid typos.
    #
    #  SCOPES = Bridger::Scopes::Tree.new('bootic') do |bootic|
    #    api = 'api'
    #    products = 'products'
    #    orders = 'orders'
    #    own = 'own'
    #    all = 'all'
    #    read = 'read'
    #
    #    bootic > api > products > own > read
    #    bootic > api > products > all > read
    #    bootic > api > orders > own > read
    #  end
    #
    # Block notation can be used where it makes sense:
    #
    #  SCOPES = Bridger::Scopes::Tree.new('bootic') do |bootic|
    #    bootic.api.products do |n|
    #      n.own do |n|
    #        n.read
    #        n.write
    #        n > 'list' # use `>` to append variables or constants
    #      end
    #    end
    #  end
    #
    # Block notation also works without explicit node argument (but can't access outer variables):
    #
    #   SCOPES = Bridger::Scopes::Tree.new('bootic') do
    #     api.products do
    #       own do
    #         read
    #         write
    #       end
    #       all do
    #         read
    #       end
    #     end
    #   end
    #
    class Tree
      ROOT_SEGMENT = 'root'

      def self.setup(object, block)
        if block.arity == 0
          object.instance_eval(&block)
        else
          block.call(object)
        end
      end

      attr_reader :__root

      TransientRecorder = Data.define(:__segment, :__children) do
        def to_s
          __segment
        end
      end

      InvalidScopeHierarchyError = Class.new(::StandardError)

      class Node < BasicObject
        attr_reader :__parent, :to_s, :to_a

        def initialize(recorder, parent = nil)
          @__recorder = recorder
          @__parent = parent
          @to_s = [@__parent, @__recorder].compact.map(&:to_s).join('.')
          @to_a = @__parent ? @__parent.to_a + [@__recorder.__segment] : [@__recorder.__segment]
        end

        def *
          Node.new(TransientRecorder.new('*', __shared_grandchildren), self)
        end

        def _value(values)
          child = @__recorder.__children.find { |r| r.match?(values) }
          if !child
            ::Kernel.raise ::Bridger::Scopes::Tree::InvalidScopeHierarchyError, "invalid free value segment '#{values}' after #{self}. Supported segments here are #{@__recorder.__children.map { |e| "'#{e}'" }.join(', ')}"
          end

          values = "(#{values.join(',')})" if values.is_a?(::Array)
          Node.new(TransientRecorder.new(values.to_s, child.__children), self)
        end

        def call(...)
          _value(...)
        end

        def inspect
          %(<Bridger::Scopes::Tree::Node [#{to_s}]>)
        end

        def respond_to?(method_name, include_private = true)
          method_name == :to_scope
        end

        def to_scope
          ::Bridger::Scopes::Scope.new(to_a)
        end

        def hash
          to_s.hash
        end

        def respond_to_missing?(method_name, include_private = true)
          true
        end

        def method_missing(method_name, *args)
          ::Kernel.raise ::NoMethodError, "undefined method `#{method_name}' for #{self} with args #{args.inspect}" if args.any?

          _value(method_name, *args)
        end

        private

        def __shared_grandchildren
          shared_segments = @__recorder.__children.map{ |e| e.__children.map(&:__segment) }.reduce(:&)
          @__recorder.__children.flat_map(&:__children).each.filter do |child|
            shared_segments.include?(child.__segment)
          end
        end
      end

      # @param root_segment [String] the name of the root node
      # @param config [Proc] a block to define the scope hierarchy
      def initialize(root_segment = ROOT_SEGMENT, &config)
        @recorder = Recorder.new(root_segment)
        Tree.setup(@recorder, config) if block_given?
        @root = Node.new(@recorder)
        define_singleton_method(root_segment) { @root }
        @recorder.freeze
        freeze
      end

      private

      # A Recorder is used within the block passed to Tree.new
      # to record the hierarchy of scopes.
      # It is a BasicObject so that it can be used with dot notation.
      class Recorder < BasicObject
        attr_reader :__segment, :__children, :__info

        # @param segment [String] the name of the node
        # @param block [Proc] a block to define the scope hierarchy. Optional.
        def initialize(matchers, &block)
          @__matchers = [matchers].flatten
          @__segment = @__matchers.first.to_s
          @__info = @__matchers.size > 1 ? %((#{@__matchers.map(&:to_s).join(',')})) : @__segment
          @__children = []
          @__frozen = false
          Tree.setup(self, block) if ::Kernel.block_given?
        end

        def freeze
          @__children.each(&:freeze)
          @__children.freeze
          self
        end

        # @param segment [String] the name of the child node
        def >(segment)
          __register(Recorder.new(segment))
        end

        def _any(constraints = [], &block)
          constraints = [constraints] unless constraints.is_a?(::Array)
          __register(Recorder.new(constraints, &block))
        end

        def method_missing(method_name, *_args, &block)
          __register(Recorder.new(method_name.to_s, &block))
        end

        def respond_to_missing?(method_name, include_private = false)
          true
        end

        def match?(values)
          values = [values] unless values.is_a?(::Array)
          values = values.map(&:to_s)
          @__matchers.empty? || @__matchers.any? { |matcher| values.all? { |v| matcher === v } }
        end

        def to_s
          __info
        end

        def to_str
          to_s
        end

        def inspect
          %(<Bridger::Scopes::Tree::Recorder #{to_s} [#{__children.join(', ')}]>)
        end

        private def __register(child_recorder)
          @__children << child_recorder
          child_recorder
        end
      end
    end
  end
end
