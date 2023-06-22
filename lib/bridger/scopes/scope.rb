# frozen_string_literal: true

module Bridger
  class Scopes
    class Scope
      SEP = '.'.freeze
      WILDCARD = '*'.freeze

      include Comparable

      def initialize(sc)
        @segments = sc.is_a?(Array) ? sc : sc.split(SEP)
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
