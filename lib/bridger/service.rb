require "bridger/authorizers"
require 'bridger/default_serializers'
require 'bridger/default_actions'

module Bridger
  class Service
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
      return enum_for(:each) unless block_given?

      endpoints.each &block
    end

    def all
      endpoints
    end

    def [](name)
      lookup[name]
    end

    def schema_endpoints(path: '/schemas', scope: nil)
      endpoint(:schemas, :get, path,
               title: 'API schemas',
               scope: scope,
               action: DefaultActions::PassThrough.new(self),
               serializer: DefaultSerializers::Endpoints
              )

      endpoint(:schema, :get, "#{path}/:rel",
               title: 'API schema',
               scope: scope,
               action: DefaultActions::Schema.new(self),
               serializer: DefaultSerializers::Endpoint
              )
    end

    def endpoint(name, verb, path, title:, scope: nil, action: nil, serializer:)
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
