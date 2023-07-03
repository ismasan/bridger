# frozen_string_literal: true

require 'bridger/serializer'
require 'bridger/json_schema_generator'

module Bridger
  module DefaultSerializers
    class ErrorSerializer < ::Bridger::Serializer
      class ErrorsWrapper
        include Enumerable

        def initialize(errors)
          @errors = errors
        end

        def each(&block)
          @errors.each do |field, messages|
            yield({field: field, messages: messages})
          end
        end
      end

      def self.wrap(errors)
        ErrorsWrapper.new(errors)
      end

      schema do
        type ['error']
        properties do |props|
          props._from item
        end
      end
    end

    class Success < ::Bridger::Serializer
      schema do
        type ['success'].freeze

        properties do |props|
          props._from item if item
          props.message 'Hello World!'
        end
      end
    end

    # TODO: rename this to Forbidden.
    # Best to match status code names.
    class AccessDenied < ::Bridger::Serializer
      DEFAULT_MESSAGE = 'Access denied. Insufficient permissions to access this resource'.freeze

      schema do
        type ['errors', 'forbidden'].freeze

        properties do |props|
          props.message 'Forbidden'
        end

        entities(
          :errors,
          [{field: 'access_token', messages:['Access denied. Access token is valid but has insufficient permissions.']}],
          ErrorSerializer
        )
      end
    end

    class Unauthorized < ::Bridger::Serializer
      schema do
        type ['errors', 'unauthorized']

        properties do |props|
          props.message 'Unauthorized'
        end

        entities(
          :errors,
          [{field: 'access_token', messages:['Access denied. Missing or invalid access token.']}],
          ErrorSerializer
        )
      end
    end

    class ServerError < ::Bridger::Serializer
      schema do
        type ['errors', 'serverError', item&.class&.name].compact

        properties do |props|
          props.message item&.message
        end

        entities(
          :errors,
          [{field: '$', messages:[item&.message]}],
          ErrorSerializer
        )
      end
    end

    NoContent = proc do |_, auth:, h:|
      {}
    end

    class TooManyRequests < ::Bridger::Serializer
      schema do
        type ['errors', 'tooManyRequests']
      end
    end

    class NotFound < ::Bridger::Serializer
      schema do
        type ['errors', 'notFound']

        entities(
          :errors,
          [{field: '$', messages:['Not found']}],
          ErrorSerializer
        )
      end
    end

    class InvalidPayload < ::Bridger::Serializer
      def self.call(result, context = {})
        new(result, context).to_hash
      end

      schema do
        type ['errors', 'invalid']

        entities :errors, ErrorSerializer.wrap(item.errors), ErrorSerializer
      end
    end

    class Endpoints < ::Bridger::Serializer
      schema do
        type ["results", "endpoints"]

        items item.all do |endpoint, s|
          s.rel :schema, rel: endpoint.name, as: :self

          s.property :rel, endpoint.name
          s.property :title, endpoint.title
          s.property :verb, endpoint.verb
          s.property :scope, endpoint.scope.to_s

          s.property :templated, endpoint.relation.templated?
          s.property :href, url(endpoint.relation.path)
        end
      end
    end

    class Endpoint < ::Bridger::Serializer
      schema do
        type ["endpoint"]

        rel :schema, rel: item.name, as: :self

        property :rel, item.name
        property :title, item.title
        property :verb, item.verb
        property :scope, item.scope.to_s

        property :templated, item.relation.templated?
        property :href, url(item.relation.path)

        property :query_schema, json_schema_for(item.query_schema)
        property :payload_schema, json_schema_for(item.payload_schema)
      end

      private
      def json_schema_for(schema)
        ::Bridger::JsonSchemaGenerator.generate(schema)
      end
    end
  end
end
