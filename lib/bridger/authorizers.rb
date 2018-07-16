module Bridger
  module Authorizers
    class Tree
      def initialize(&block)
        @branches = {}
        @checks = []
        instance_eval(&block) if block_given?
      end

      def t(name, &block)
        branches[name] = self.class.new(&block)
      end

      def check(&block)
        checks << block
        self
      end

      def at(scope, &block)
        segments = parse_segments(scope)

        branch = segments.reduce(self) do |b, segment|
          br = branches[segment]
          if br # exists
            br
          else # new branch
            b.t(segment)
          end
        end

        branch.check &block
      end

      def authorized?(scope, *args)
        return false unless checks.all?{|ch| ch.call(scope, *args) }

        segments = parse_segments(scope)

        segment = segments.shift
        branch = branches[segment]

        return true unless branch

        branch.authorized? segments, *args
      end

      private
      attr_reader :branches, :checks

      def parse_segments(segments)
        segments.is_a?(String) ? segments.split('.') : segments.to_a
      end
    end
  end
end
