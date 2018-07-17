module Bridger
  class Scopes
    include Comparable

    def initialize(scopes)
      @scopes = scopes.map{|sc|
        Scope.new(sc)
      }.sort{|a,b| b <=> a}
    end

    def resolve(scope)
      sc = scope.is_a?(String) ? Scope.new(scope) : scope
      scopes.find{|s| s >= sc }
    end

    def can?(another)
      self >= another
    end

    def <=>(another)
      # find first scope that is higher than any scopes in another
      hit = scopes.find{|s1| another.scopes.any?{|s2| s1 >= s2}}
      hit ? 1 : -1
    end

    def to_s
      @to_s ||= scopes.join(', ')
    end

    def to_a
      @to_a ||= scopes.map &:to_s
    end

    private
    attr_reader :scopes

    class Scope
      SEP = '.'.freeze
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
        diff = segments - another_scope.segments
        if diff.size == 0
          1
        else
          -1
        end
      end

      protected

      attr_reader :segments
    end

    class Aliases
      def initialize(mapping = {})
        @mapping = mapping
      end

      def map(scopes)
        Array(scopes.to_a).reduce([]){|memo, sc|
          memo + Array(@mapping.fetch(sc, sc))
        }.uniq
      end
    end
  end
end
