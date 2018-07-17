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

    class AccessDenied < ::Bridger::Serializer
      DEFAULT_MESSAGE = 'Access denied. Missing or invalid access token.'.freeze

      schema do
        type ['errors', 'accessDenied']

        properties do |props|
          props.message "Access denied"
        end

        entities(
          :errors,
          errors(item),
          ErrorSerializer
        )
      end

      def errors(exception)
        [
          {
            field: 'access_token',
            messages:[DEFAULT_MESSAGE, exception.message]
          }
        ]
      end
    end

    class Unauthorized < ::Bridger::Serializer
      schema do
        type ['errors', 'accessDenied']

        properties do |props|
          props.message "Access denied"
        end

        entities(
          :errors,
          [{field: 'access_token', messages:['Access denied. Missing or invalid access token.']}],
          ErrorSerializer
        )
      end
    end

    class InvalidPayload < ::Bridger::Serializer
      schema do
        type ['errors', 'invalid']

        entities :errors, ErrorSerializer.wrap(item.errors), ErrorSerializer
      end
    end

    class Endpoints < ::Bridger::Serializer
      schema do
        type ["results", "endpoints"]

        items item.all do |endpoint, s|
          s.link :self, href: url("/schemas/#{endpoint.name}")

          s.property :rel, endpoint.name
          s.property :title, endpoint.title
          s.property :method, endpoint.verb
          s.property :scope, endpoint.scope.to_s

          s.property :templated, endpoint.relation.templated?
          s.property :href, url(endpoint.relation.path)
        end
      end
    end

    class Endpoint < ::Bridger::Serializer
      schema do
        type ["endpoint"]

        link :self, href: url("/schemas/#{item.name}")

        property :rel, item.name
        property :title, item.title
        property :method, item.verb
        property :scope, item.scope.to_s

        property :templated, item.relation.templated?
        property :href, url(item.relation.path)

        property :input_schema, json_schema_for(item.input_schema)
      end

      private
      def json_schema_for(schema)
        ::Bridger::JsonSchemaGenerator.new(schema).generate
      end
    end
  end
end
