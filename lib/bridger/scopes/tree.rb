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

      # @param root_segment [String] the name of the root node
      # @param config [Proc] a block to define the scope hierarchy
      def initialize(root_segment = ROOT_SEGMENT, &config)
        recorder = Recorder.new(root_segment)
        Tree.setup(recorder, config) if block_given?
        @root = build_tree(recorder)
        define_singleton_method(root_segment) { @root }
        freeze
      end

      private

      def build_tree(recorder, parent = nil)
        node = Node.new(recorder.__segment, parent)
        recorder.__children.values.each do |child_recorder|
          node.add_child(build_tree(child_recorder, node))
        end
        node.freeze
      end

      # Node is a BasicObject because it can be navigated using dot notation.
      # A node defines methods to access its children.
      # Ex. node.api.products.own.read
      #
      class Node < BasicObject
        attr_reader :__segment, :__children, :to_s, :to_a

        # @param segment [String] the name of the node
        # @param parent [Node] the parent node
        def initialize(segment, parent = nil)
          @__segment = segment.to_s
          @__parent = parent
          @__children = {}
          @to_a = @__parent ? @__parent.to_a + [@__segment] : [@__segment]
          @to_s = [@__parent, @__segment].compact.map(&:to_s).join('.')
        end

        def freeze
          @__children.freeze
          self
        end

        # Hash equality to make Nodes work with Aliases.
        def hash
          to_s.hash
        end

        # Wildcard node.
        # @return [Node]
        def *
          node = Node.new(::Bridger::Scopes::Scope::WILDCARD, self)
          shared_grandchildren.each do |child|
            node.add_child(child.with_parent(node))
          end
          node.freeze
        end

        # @return [Array<Node>]
        def __child_nodes
          @__children.values
        end

        # BasicObject doesn't support #respond_to?.
        # This is needed to support consumers of nodes to user #to_scope.
        #
        # @param method_name [Symbol] the name of the method
        def respond_to?(method_name, include_private = false)
          method_name == :to_scope ? true : super
        end

        # Turn a node into a Scope, so that it can be used
        # by endpoints.
        # @return [Scope]
        def to_scope
          ::Bridger::Scopes::Scope.new(to_a)
        end

        # Add a child node and define a method to access it.
        #
        # @param node [Node] the child node
        def add_child(node)
          @__children[node.__segment] = node
          instance_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{node.__segment}
              @__children['#{node.__segment}']
            end
          RUBY
        end

        protected

        # @param parent [Node] the parent node
        # @return [Node] with new parent
        def with_parent(parent)
          Node.new(@__segment, parent)
        end

        private

        def shared_grandchildren
          shared_segments = __child_nodes.map { |c|
            c.__child_nodes.map(&:__segment)
          }.reduce(:&)

          __child_nodes.flat_map { |c|
            c.__child_nodes.select { |cc|
              shared_segments.include?(cc.__segment)
            }
          }
        end
      end

      # A Recorder is used within the block passed to Tree.new
      # to record the hierarchy of scopes.
      # It is a BasicObject so that it can be used with dot notation.
      class Recorder < BasicObject
        attr_reader :__segment, :__children

        # @param segment [String] the name of the node
        # @param block [Proc] a block to define the scope hierarchy. Optional.
        def initialize(segment, &block)
          @__segment = segment
          @__children = {}
          Tree.setup(self, block) if ::Kernel.block_given?
        end

        # @param segment [String] the name of the child node
        def >(segment)
          __register(segment)
        end

        def method_missing(method_name, *_args, &block)
          __register(method_name, &block)
        end

        def respond_to_missing?(method_name, include_private = false)
          true
        end

        private def __register(child_name, &block)
          @__children[child_name] ||= Recorder.new(child_name, &block)
        end

      end
    end
  end
end
