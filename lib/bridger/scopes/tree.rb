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
    #  )
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
    class Tree
      ROOT_SEGMENT = 'root'

      def initialize(root_segment = ROOT_SEGMENT, &config)
        recorder = Recorder.new(root_segment)
        config.call(recorder) if block_given?
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

      class Node < BasicObject
        attr_reader :__segment, :__children, :to_s

        def initialize(segment, parent = nil)
          @__segment = segment.to_s
          @__parent = parent
          @__children = {}
          @to_s = [@__parent, @__segment].compact.map(&:to_s).join('.')
        end

        def freeze
          @__children.freeze
          self
        end

        def *
          node = Node.new(::Bridger::Scopes::Scope::WILDCARD, self)
          @__children.values.each do |child|
            child.__children.values.each do |grandchild|
              node.add_child(grandchild.with_parent(node))
            end
          end
          node.freeze
        end

        def with_parent(parent)
          Node.new(@__segment, parent)
        end

        def to_scope
          ::Bridger::Scopes::Scope.new(to_s)
        end

        def add_child(node)
          @__children[node.__segment] = node
          instance_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{node.__segment}
              @__children['#{node.__segment}']
            end
          RUBY
        end
      end

      class Recorder < BasicObject
        attr_reader :__segment, :__children

        def initialize(segment)
          @__segment = segment
          @__children = {}
        end

        def >(segment)
          __register(segment)
        end

        def __register(child_name)
          @__children[child_name] ||= Recorder.new(child_name)
        end

        def method_missing(method_name, *args, &block)
          __register(method_name)
        end

        def respond_to_missing?(method_name, include_private = false)
          true
        end
      end
    end
  end
end
