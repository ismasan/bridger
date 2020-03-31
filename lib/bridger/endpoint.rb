require "bridger/rel_builder"
require "bridger/scopes"
require "bridger/action"

module Bridger
  class Endpoint
    MUTATING_VERBS = [:post, :put, :patch, :delete].freeze

    attr_reader :name, :verb, :path, :title, :scope, :action, :serializer

    def initialize(name:, verb:, path:, title:, scope:, action:, serializer: nil, authorizer:, instrumenter: NullInstrumenter)
      @name = name
      @verb = verb.to_sym
      @path = path
      @title = title
      @scope = scope ? Bridger::Scopes::Scope.new(scope) : nil
      @authorizer = authorizer
      @action = action || Bridger::Action
      @serializer = serializer
      @instrumenter = instrumenter
    end

    def builder
      @builder ||= RelBuilder.new(
        name,
        verb,
        path,
        query_keys,
        title
      )
    end

    def run!(query: {}, payload: {}, auth:, helper:)
      auth.authorize!(scope, authorizer, helper.params) if authenticates?

      action_name = action.is_a?(Class) ? action.name : action.class.name
      presenter = instrumenter.instrument('app.bridger.action', title: "#{action_name} #{verb.to_s.upcase} #{path}", endpoint: true, description: title) do
        action.call(query: query, payload: payload, auth: auth)
      end
      if serializer
        instrumenter.instrument('view.render.bridger.serializer', title: serializer.inspect, description: title) do
          serializer.new(presenter, h: helper, auth: auth).to_hash
        end
      end
    end

    def build_rel(opts = {})
      builder.build opts
    end

    def relation
      @relation ||= build_rel
    end

    def query_schema
      action.query_schema
    end

    def payload_schema
      action.payload_schema
    end

    def output_schema
      serializer.json_schema ? serializer.json_schema : {}
    end

    def authenticates?
      !!scope
    end

    def authorized?(auth, params)
      return true unless authenticates?
      auth.authorized?(scope) && authorizer.authorized?(scope.to_a, auth, params)
    end

    private

    attr_reader :authorizer, :instrumenter

    def query_keys
      mutating? ? [] : action.query_schema.structure.keys
    end

    def mutating?
      MUTATING_VERBS.include? verb
    end
  end
end
