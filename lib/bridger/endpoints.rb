require "bridger/authorizers"

module Bridger
  class Endpoints
    def self.instance
      @instance ||= new
    end

    def build(&block)
      instance_eval &block
      self
    end

    def initialize
      @endpoints = []
      @lookup = {}
      @authorizer = Bridger::Authorizers::Tree.new
    end

    def each(&block)
      endpoints.each &block
    end

    def all
      endpoints
    end

    def [](name)
      lookup[name]
    end

    def endpoint(name, verb, path, title:, scope: nil, action:, serializer:)
      e = Bridger::Endpoint.new(
        name: name,
        verb: verb,
        path: path,
        authorizer: authorizer,
        title: title,
        scope: scope,
        action: action,
        serializer: serializer
      )
      endpoints << e
      lookup[e.name] = e
      e
    end

    def authorize(scope, &block)
      authorizer.at(scope, &block)
    end

    private
    attr_reader :endpoints, :lookup, :authorizer
  end
end

require "bridger/endpoint"
