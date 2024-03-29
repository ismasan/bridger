# frozen_string_literal: true

require "bridger/authorizers"
require 'bridger/default_serializers'
require 'bridger/default_actions'
require 'bridger/auth'

module Bridger
  class Service
    def self.instance
      @instance ||= new
    end

    def build(&block)
      instance_eval &block
      self
    end

    attr_reader :auth_config

    def initialize
      @endpoints = []
      @lookup = {}
      @authorizer = Bridger::Authorizers::Tree.new
      @instrumenter = NullInstrumenter
      @auth_config = Auth.config
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

    def instrumenter(ins = nil)
      if ins
        raise ArgumentError, 'instrumenters must implement #instrument(name String, payload Hash, &block)' unless ins.respond_to?(:instrument)
        @instrumenter = ins
      end

      @instrumenter
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
        serializer: serializer,
        instrumenter: instrumenter
      )
      endpoints << e
      lookup[e.name] = e
      e
    end

    def authorize(scope, &block)
      authorizer.at(scope, &block)
    end

    def authenticate(config = nil, &block)
      @auth_config = config and return if config
      raise ArgumentError, 'Service#authenticate expects an Bridger::Auth::Config instance, or a block' unless block_given?

      config = Auth::Config.new
      yield config
      @auth_config = config.freeze
    end

    private
    attr_reader :endpoints, :lookup, :authorizer
  end
end

require "bridger/endpoint"
