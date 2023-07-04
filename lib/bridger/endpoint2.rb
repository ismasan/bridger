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
  class Endpoint2
    class EndpointConfig
      attr_accessor :path, :title, :verb, :scope, :action, :serializer, :auth

      def initialize
        @path = '/'
        @title = nil
        @verb = :get
        @scope = nil
        @auth = Bridger::NoopAuth
        @action = Bridger::Pipeline::NOOP
        @serializer = Bridger::SerializerSet::DEFAULT
        @instrumenter = Bridger::NullInstrumenter
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

      def serializer(value = nil, &block)
        if value
          @serializer = value
        elsif block_given?
          @serializer = @serializer.build_for(&block)
        end

        @serializer
      end
    end

    attr_reader :name, :path, :title, :verb, :scope, :serializer, :to_rack, :instrumenter, :relation

    def initialize(name, service: nil, &block)
      raise ArgumentError, 'block is required' unless block_given?

      config = EndpointConfig.new
      yield config

      @name = name
      @service = service
      @path = config.path
      @title = config.title
      @verb = config.verb
      @scope = config.scope
      @auth = config.auth
      @action = config.action
      @serializer = config.serializer
      @instrumenter = config.instrumenter

      @pipeline = Bridger::Pipeline.new(instrumenter:) do |pl|
        pl.instrument('bridger.endpoint', name:, path:, verb:, scope: @scope.to_s) do |pl|
          pl.step Bridger::Pipeline::AuthorizationStep.new(@auth, @scope) if @scope
          pl.step Bridger::Pipeline::AssignQueryStep
          pl.instrument(Bridger::Pipeline::ParsePayloadStep.new, 'bridger.endpoint.parse_payload') if (@verb == :post || @verb == :put)
          pl.instrument('bridger.endpoint.validate_inputs') do |pl|
            pl.step Bridger::Pipeline::Validations::Query.new(@action.query_schema) if @action.respond_to?(:query_schema)
            pl.step Bridger::Pipeline::Validations::Payload.new(@action.payload_schema) if @action.respond_to?(:payload_schema)
          end
          pl.instrument(@action, 'bridger.endpoint.action', info: @action.to_s)
          pl.continue
          pl.instrument('bridger.endpoint.serializer') do |pl|
            pl.step do |result|
              serializer.run(result, service: @service, rel_name: @name)
            end
          end
        end
      end

      @to_rack = RackHandler.new(self)

      query_keys = @action.respond_to?(:query_schema) ? @action.query_schema.structure.keys : []
      @builder = RelBuilder.new(
        name,
        verb,
        path,
        query_keys,
        title
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
