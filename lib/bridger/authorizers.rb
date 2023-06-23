# frozen_string_literal: true

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
        scope = Bridger::Scopes::Scope.wrap(scope)

        branch = scope.to_a.reduce(self) do |b, segment|
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
        scope = Bridger::Scopes::Scope.wrap(scope)
        return false unless checks.all?{|ch| ch.call(scope, *args) }

        segments = scope.to_a
        segment = segments.shift
        branch = branches[segment]

        return true unless branch

        branch.authorized? segments, *args
      end

      private

      attr_reader :branches, :checks
    end
  end
end
