# frozen_string_literal: true

require "bridger/authorizers"
require 'bridger/default_serializers'
require 'bridger/default_actions'
require 'bridger/auth'
require 'bridger/endpoint'

module Bridger
  class Service
    def self.instance
      @instance ||= new
    end

    def build(&block)
      instance_eval &block
      self
    end

    attr_reader :auth_config, :exception_endpoint

    def initialize
      @endpoints = []
      @lookup = {}
      @authorizer = Bridger::Authorizers::Tree.new
      @instrumenter = NullInstrumenter
      @auth_config = Auth.config
      @serializers = Bridger::SerializerSet.new(parent: Bridger::SerializerSet::DEFAULT)
      @exception_endpoint = Bridger::Endpoint.new(:__exceptions, service: self, serializer: @serializers)
    end

    # TODO: test this
    def render_exception(exception, request, status: 500)
      result = ::Bridger::Result::Success.build(request:).continue(status:) do |r|
        r[:exception] = exception
      end
      exception_endpoint.call(result).response.finish
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

    def serializers(set = nil, &block)
      if set
        @serializers = set
      elsif block_given?
        @serializers = @serializers.build_for(&block)
      end

      @serializers
    end

    def endpoint(name, verb, path, title: name, scope: nil, action: nil, serializer: nil, &block)
      # TODO: if passed a SerializerSet, merge it with the service's set.
      serializer = if serializer
        serializers.build_for do |r|
          r.on((200..201), serializer)
        end
      else
        serializers
      end

      ep = Bridger::Endpoint.new(
        name,
        verb:,
        path:,
        title:,
        auth: auth_config,
        scope:,
        action:,
        serializer:,
        service: self,
        instrumenter:,
        &block
      )

      endpoints << ep
      lookup[ep.name] = ep
      ep
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
