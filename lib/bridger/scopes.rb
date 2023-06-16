# frozen_string_literal: true

module Bridger
  class Scopes
    include Comparable

    def self.wrap(sc)
      case sc
      when String, Scope
        new([sc])
      when Array
        new(sc)
      when Scopes
        sc
      else
        raise ArgumentError, "Can't compare #{sc.inspect} with #{self.name}"
      end
    end

    def initialize(scopes)
      @scopes = scopes.map{|sc|
        sc.is_a?(Scope) ? sc : Scope.new(sc)
      }.sort{|a,b| b <=> a}
    end

    def resolve(scope)
      sc = scope.is_a?(String) ? Scope.new(scope) : scope
      scopes.find{|s| s >= sc }
    end

    def any?(&block)
      scopes.any? &block
    end

    def all?(&block)
      scopes.all? &block
    end

    def can?(another)
      another = self.class.wrap(another)
      !!scopes.find{|s1| another.any?{|s2| s1 >= s2}}
    end

    def <=>(another)
      another = self.class.wrap(another)
      hit = scopes.find{|s1| another.all?{|s2| s1 >= s2}}
      hit ? 1 : -1
    end

    def to_s
      @to_s ||= scopes.join(', ')
    end

    def to_a
      @to_a ||= scopes.map &:to_s
    end

    protected
    attr_reader :scopes

    private

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

    class Aliases
      def initialize(mapping = {})
        @mapping = mapping
      end

      def map(scopes)
        scpes = Array(scopes.to_a).reduce([]){|memo, sc|
          memo + Array(@mapping.fetch(sc, sc))
        }.uniq

        Scopes.wrap(scpes)
      end
    end
  end
end
