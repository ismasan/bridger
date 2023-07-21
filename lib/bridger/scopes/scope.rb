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

      def initialize(segments)
        @segments = segments.map { |v| Segment.wrap(v) }
      end

      def to_scope
        self
      end

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

      def can?(another_scope)
        self >= another_scope
      end

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
