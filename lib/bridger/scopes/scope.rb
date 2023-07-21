# frozen_string_literal: true

module Bridger
  class Scopes
    class Scope
      SEP = '.'
      WILDCARD = '*'
      ARRAY_EXPR = /\((.+)\)$/ # '(1,2,3)'
      COMMA = ','
      COLON = ':'

      include Comparable

      # A scope segment is a single part of a scope, e.g. 'foo' or '(1,2,3)'
      Segment = Data.define(:name, :values) do
        # 'foo'
        # '(1,2,3)'
        # '*'
        def self.wrap(name)
          return name if name.is_a?(self)

          if name.is_a?(Array)
            new("(#{name.join(COMMA)})", name.map(&:to_s))
          elsif name.to_s =~ ARRAY_EXPR
            new(name, $1.split(COMMA))
          elsif name == WILDCARD
            new(name, [])
          else
            new(name, [name.to_s])
          end
        end

        def ==(other)
          return true if name == WILDCARD || other.name == WILDCARD

          # [1,2,3] >= [1]
          (values & other.values).any?
        end

        def to_s
          name
        end
      end

      # A scope is a list of segments, e.g. 'foo.bar.baz'
      # It can be initialized with a string, an array of strings, or a symbol
      # It can also be initialized with another scope
      # It can be expanded with a hash of values
      # It can be compared with another scope
      # It can be converted to a string
      # It can be converted to an array of strings
      #
      # @param [String, Array<String>, Symbol, Scope] sc
      # @return [Scope]
      def self.wrap(sc)
        case sc
          in Scope
            sc
          in Array => list
            new(sc)
          in String
            new(sc.split(SEP))
          in Symbol
            new([sc.to_s])
          else
            if sc.respond_to?(:to_scope)
              sc.to_scope
            else
              raise ArgumentError, "Can't turn #{sc.inspect} into a Scope"
            end
        end
      end

      # @param [Array<Segment, String>] segments
      def initialize(segments)
        @segments = segments.map { |v| Segment.wrap(v) }
      end

      # @return [Scope]
      def to_scope
        self
      end

      # Expand a scope with a hash of values and return a new scope
      # If a segment is not present in the hash, it will be left as-is
      #
      # @example
      #   scope = Scope.new('root.foo.bar.baz')
      #   scope.expand('foo' => 1, 'bar' => [2, 3]) # => Scope.new('root.1.bar.(2,3)')
      #
      # @param [Hash] attrs
      # @return [Scope]
      def expand(attrs = {})
        segments = self.segments.map do |segment|
          if value = attrs[segment.to_s]
            Segment.wrap(value)
          else
            segment
          end
        end

        self.class.new(segments)
      end

      def inspect
        %(<#{self.class.name}##{object_id} [#{to_s}]>)
      end

      def to_s
        to_a.join(SEP)
      end

      def to_a
        segments.map(&:to_s)
      end

      # @param [Scope] another_scope
      # @return [Boolean]
      def can?(another_scope)
        self >= another_scope
      end

      # Make [Scope] comparable
      #
      # @param [Scope] another_scope
      # @return [Integer]
      def <=>(another_scope)
        a, b = segments, another_scope.segments
        return -1 if a.size > b.size

        all_match = a.each_with_index.all? { |segment, i| segment == b[i] }
        return -1 unless all_match

        a.size < b.size ? 1 : 0
      end

      protected

      attr_reader :segments
    end
  end
end
