# frozen_string_literal: true

require 'bridger/scopes/scope'
require 'bridger/scopes/aliases'

module Bridger
  class Scopes
    include Comparable

    def self.wrap(sc)
      case sc
      when String, Scope
        new([sc])
      when Symbol
        new([sc.to_s])
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
        sc.respond_to?(:to_scope) ? sc.to_scope : Scope.new(sc)
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

    def inspect
      %(<#{self.class.name}##{object_id} [#{to_s}]>)
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
