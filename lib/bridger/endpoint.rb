# frozen_string_literal: true

require 'bridger/rack_handler'
require "bridger/rel_builder"
require 'bridger/pipeline'
require 'bridger/pipeline/authorization_step'
require 'bridger/pipeline/assign_query_step'
require 'bridger/pipeline/parse_payload_step'
require 'bridger/pipeline/validations'
require 'bridger/serializer_set'

module Bridger
  class Endpoint
    class EndpointConfig
      attr_reader :path, :title, :verb, :scope, :action, :auth
      attr_accessor :serializer

      def initialize
        @path = nil
        @title = nil
        @verb = nil
        @scope = nil
        @auth = nil
        @action = nil
        @serializer = Bridger::SerializerSet.new(parent: Bridger::SerializerSet::DEFAULT)
        @instrumenter = nil
      end

      def path(value = nil)
        @path = value if value
        @path
      end

      def title(value = nil)
        @title = value if value
        @title
      end

      def verb(value = nil)
        @verb = value if value
        @verb
      end

      def scope(value = nil)
        @scope = Bridger::Scopes::Scope.wrap(value) if value
        @scope
      end

      def instrumenter(object = nil)
        if object
          raise ArgumentError, 'instrumenter must implement #instrument' unless object.respond_to?(:instrument)
          @instrumenter = object
        end
        @instrumenter
      end

      def auth(config = nil, &block)
        return @auth unless config || block_given?

        @auth = if config
          config
        elsif block_given?
          config = Bridger::Auth::Config.new
          yield config
          config.freeze
        end

        @auth
      end

      def action(value = nil, &block)
        return @action unless value || block_given?

        @action = value if value
        # TODO: dedicated Action pipeline that supports schemas?
        @action = Pipeline.new(instrumenter:, &block) if block_given?

        unless @action.respond_to?(:call)
          raise ArgumentError, 'action must implement #call(Bridger::Result) -> Bridger::Result'
        end

        @action
      end

      def serialize(status, srz = nil, &block)
        @serializer.on(status, srz, &block)
        self
      end
    end

    attr_reader :name, :path, :title, :verb, :scope, :serializer, :to_rack, :instrumenter, :relation

    def initialize(
      name,
      path: '/',
      title: nil,
      verb: :get,
      scope: nil,
      auth: nil,
      action: Bridger::Pipeline::NOOP,
      serializer: nil,
      instrumenter: Bridger::NullInstrumenter,
      service: nil,
      &block)

      config = EndpointConfig.new

      @name = name
      @path = path
      @title = title
      @verb = verb
      @scope = scope ? Bridger::Scopes::Scope.wrap(scope) : nil
      @auth = auth
      @action = action
      @instrumenter = instrumenter
      @service = service

      yield config if block_given?

      @path = config.path if config.path
      @title = config.title if config.title
      @verb = config.verb if config.verb
      @scope = config.scope if config.scope
      @auth = config.auth if config.auth
      @action = config.action if config.action
      @serializer = if serializer # Service serializer given
                      serializer >> config.serializer
                    else
                      config.serializer
                    end
      @instrumenter = config.instrumenter if config.instrumenter

      @pipeline = Bridger::Pipeline.new(instrumenter: @instrumenter) do |pl|
        pl.instrument('bridger.endpoint', name: @name, path: @path, verb: @verb, scope: @scope.to_s) do |pl|
          pl.step Bridger::Pipeline::AuthorizationStep.new(@auth, @scope) if @auth && @scope
          pl.step Bridger::Pipeline::AssignQueryStep
          pl.instrument(Bridger::Pipeline::ParsePayloadStep.new, 'bridger.endpoint.parse_payload') if (@verb == :post || @verb == :put || @verb == :patch)
          pl.instrument('bridger.endpoint.validate_inputs') do |pl|
            pl.step Bridger::Pipeline::Validations::Query.new(@action.query_schema) if @action.respond_to?(:query_schema)
            pl.step Bridger::Pipeline::Validations::Payload.new(@action.payload_schema) if @action.respond_to?(:payload_schema)
          end
          pl.instrument(@action, 'bridger.endpoint.action', info: @action.to_s) if @action
          pl.continue
          pl.instrument('bridger.endpoint.serializer') do |pl|
            pl.step do |result|
              @serializer.run(result, service: @service, rel_name: @name)
            end
          end
        end
      end

      @to_rack = RackHandler.new(self)

      query_keys = @action.respond_to?(:query_schema) ? @action.query_schema.structure.keys : []
      @builder = RelBuilder.new(
        @name,
        @verb,
        @path,
        query_keys,
        @title
      )
      @relation = build_rel
    end

    def inspect
      %(#<#{self.class.name}:#{object_id} name: #{name} path: #{verb} #{path} (#{scope})>)
    end

    def build_rel(opts = {})
      builder.build opts
    end

    def query_schema
      @action.query_schema
    end

    def payload_schema
      @action.payload_schema
    end

    def call(result)
      @pipeline.call(result)
    end

    def authenticates?
      !!scope
    end

    def authorized?(auth, params)
      return true unless authenticates?

      auth.authorized?(scope)
    end

    private

    attr_reader :builder
  end
end
