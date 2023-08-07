# frozen_string_literal: true

require 'forwardable'
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
      extend Forwardable

      def_delegators :@action, :step, :step!, :pipeline, :instrument, :continue, :halt, :query_schema, :payload_schema
      attr_reader :action, :auth
      attr_accessor :serializer

      def initialize(instrumenter:)
        @auth = nil
        @instrumenter = instrumenter
        @action = Bridger::Pipeline.new(instrumenter:)
        @serializer = Bridger::SerializerSet.new(parent: Bridger::SerializerSet::DEFAULT)
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

      def serialize(status, srz = nil, &block)
        @serializer.on(status, srz, &block)
        self
      end
    end

    extend Forwardable

    def_delegators :@config, :action, :auth
    attr_reader :path, :title, :verb, :scope, :instrumenter, :name, :serializer, :to_rack, :relation, :service

    def initialize(
      name,
      path: '/',
      title: nil,
      verb: :get,
      scope: nil,
      auth: nil,
      action: nil,
      serializer: nil,
      instrumenter: Bridger::NullInstrumenter,
      service: nil,
      &block)

      raise ArgumentError, 'instrumenter must implement #instrument' unless instrumenter.respond_to?(:instrument)

      @config = EndpointConfig.new(instrumenter:)

      @name = name
      @service = service
      @path = path
      @title = title
      @verb = verb
      @scope = scope ? Bridger::Scopes::Scope.wrap(scope) : nil
      @instrumenter = instrumenter
      @config.auth auth
      @config.action.step action if action

      yield @config if block_given?
      @config.action.freeze

      @serializer = if serializer # Service serializer given
                      serializer >> @config.serializer
                    else
                      @config.serializer
                    end

      @pipeline = Bridger::Pipeline.new(instrumenter: @instrumenter) do |pl|
        pl.instrument('bridger.endpoint', name: @name, path: @path, verb: @verb, scope: @scope.to_s) do |pl|
          pl.step Bridger::Pipeline::AuthorizationStep.new(@config.auth, @scope) if @config.auth && @scope
          pl.step Bridger::Pipeline::AssignQueryStep
          pl.instrument(Bridger::Pipeline::ParsePayloadStep.new, 'bridger.endpoint.parse_payload') if (@verb == :post || @verb == :put || @verb == :patch)
          pl.instrument('bridger.endpoint.validate_inputs') do |pl|
            pl.step Bridger::Pipeline::Validations::Query.new(@config.action.query_schema) if @config.action.respond_to?(:query_schema)
            pl.step Bridger::Pipeline::Validations::Payload.new(@config.action.payload_schema) if @config.action.respond_to?(:payload_schema)
          end
          pl.instrument(@config.action, 'bridger.endpoint.action', info: @config.action.to_s) if @config.action
          pl.continue
          pl.instrument('bridger.endpoint.serializer') do |pl|
            pl.step do |result|
              @serializer.run(result, service: @service, rel_name: @name)
            end
          end
        end
      end

      @to_rack = RackHandler.new(self)

      query_keys = @config.action.respond_to?(:query_schema) ? @config.action.query_schema.structure.keys : []
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
      @config.action.query_schema
    end

    def payload_schema
      @config.action.payload_schema
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
