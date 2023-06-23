# frozen_string_literal: true

module Bridger
  class Scopes
    class Scope
      SEP = '.'
      WILDCARD = '*'

      include Comparable

      def self.wrap(sc)
        case sc
          in Scope
            sc
          in Array => list if list.all?{|s| s.is_a?(String) }
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
        @segments = segments
      end

      def to_scope
        self
      end

      def to_s
        segments.join(SEP)
      end

      def to_a
        segments.dup
      end

      def can?(another_scope)
        self >= another_scope
      end

      def <=>(another_scope)
        a, b = segments, another_scope.segments
        return -1 if a.size > b.size

        a = equalize(a, b)
        b = equalize(b, a)
        diff = a - b
        diff.size == 0 ? 1 : -1
      end

      protected

      attr_reader :segments

      private

      def equalize(a, b)
        shortest = [a.size, b.size].min
        0.upto(shortest - 1).map { |i| a[i] == WILDCARD ? b[i] : a[i] }
      end
    end
  end
end
