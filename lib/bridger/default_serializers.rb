require 'bridger/serializer'

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
  end
end
