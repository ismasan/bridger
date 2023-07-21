# frozen_string_literal: true

require 'bridger/scopes/scope'
require 'bridger/scopes/aliases'
require 'bridger/scopes/tree'

module Bridger
  class Scopes
    include Comparable

    def self.wrap(sc)
      if sc.is_a?(Scopes)
        sc
      else
        new(sc)
      end
    end

    # @param scopes [Array<Scope, String>]
    def initialize(scopes)
      @scopes = [scopes].flatten.map { |s| Scope.wrap(s) }.sort{ |a, b| b <=> a}
    end

    def resolve(scope)
      sc = Scope.wrap(scope)
      scopes.find { |s| s >= sc }
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

    def inspect
      %(<#{self.class.name}##{object_id} [#{to_s}]>)
    end

    def expand(attrs = {})
      scp = scopes.map { |s| s.expand(attrs) }
      self.class.new(scp)
    end

    def to_s
      @to_s ||= scopes.join(', ')
    end

    def to_a
      @to_a ||= scopes.map &:to_s
    end

    protected

    attr_reader :scopes
  end
end
