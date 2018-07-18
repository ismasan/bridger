require "bridger/rel_builder"

module Bridger
  class Endpoint
    MUTATING_VERBS = [:post, :put, :patch, :delete].freeze

    attr_reader :name, :verb, :path, :title, :scope, :action, :serializer

    def initialize(name:, verb:, path:, title:, scope:, action:, serializer:, authorizer:)
      @name = name
      @verb = verb.to_sym
      @path = path
      @title = title
      @scope = scope
      @authorizer = authorizer
      @action = action
      @serializer = serializer
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

    def run!(payload: {}, auth:, helper:)
      auth.authorize!(scope, authorizer, helper.params) if authenticates?

      presenter = action.run!(payload: payload, auth: auth)
      serializer ? serializer.new(presenter, h: helper, auth: auth) : nil
    end

    def build_rel(opts = {})
      builder.build opts
    end

    def relation
      @relation ||= build_rel
    end

    def input_schema
      action.schema
    end

    def output_schema
      serializer.json_schema ? serializer.json_schema : {}
    end

    def authenticates?
      !!scope
    end

    def authorized?(auth, params)
      authorizer.authorized?(scope.to_a, auth, params)
    end

    private

    attr_reader :authorizer

    def query_keys
      mutating? ? [] : action.schema.structure.keys
    end

    def mutating?
      MUTATING_VERBS.include? verb
    end
  end
end
