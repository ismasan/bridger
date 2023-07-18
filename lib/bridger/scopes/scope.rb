# frozen_string_literal: true

module Bridger
  class Scopes
    class Scope
      SEP = '.'
      WILDCARD = '*'
      TEMPLATE_EXPR = /<(.+)>$/
      COMMA = ','
      COLON = ':'

      include Comparable

      Segment = Data.define(:name, :key, :values) do
        def self.wrap(name)
          return name if name.is_a?(self)

          key, value = name.split(COLON, 2)
          if value == WILDCARD
            new(name, key, [])
          elsif value
            new(name, key, value.split(COMMA))
          else
            new(name, key, [])
          end
        end

        def ==(other)
          return true if key == WILDCARD || other.key == WILDCARD

          # 'shops:1,2,3' >= 'shops:1'
          # 'shops' >= 'shops:1'
          # 'shops:1,2,3' >= 'shops'
          (key == other.key) && (values.empty? && other.values.empty?) || (values & other.values).any?
        end

        def to_s
          name
        end
      end

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
        @segments = segments.map { |v| Segment.wrap(v) }
      end

      def to_scope
        self
      end

      # Replace segments in the format `foo:<key>` with the value of the key in the given hash
      def expand(attrs = {})
        segments = self.segments.map do |segment|
          segment = segment.to_s
          if segment =~ TEMPLATE_EXPR
            key = $1.to_sym
            raise ArgumentError, "Missing value for #{key}" unless attrs.key?(key)

            value = attrs[key]
            value = value.join(',') if value.is_a?(Array)
            segment.gsub(TEMPLATE_EXPR, value.to_s)
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
