# frozen_string_literal: true

module Bridger
  class Pipeline
    class SchemaSteps
      # @param schema [Parametric::Schema] a pipeline's query or payload schema
      # @param block [Proc] an optional block to build a schema from
      def initialize(schema, &block)
        schema ||= (block_given? ? Parametric::Schema.new(&block) : nil)
        raise ArgumentError, 'Schema steps expect a schema object or a block' unless schema

        @schema = schema
      end

      # The Step interface #call(Result) Result
      # @param result [Result]
      # @returns Result
      def call(result)
        data = result.public_send(key)
        resolved = schema.resolve(data)
        return result.halt(errors: result.errors.merge(resolved.errors)) unless resolved.valid?

        result.continue(key => data.merge(resolved.output))
      end

      private

      attr_reader :schema

      class Query < self
        def query_schema; schema; end

        private

        def key
          :query
        end
      end

      class Payload < self
        def payload_schema; schema; end

        private

        def key
          :payload
        end
      end
    end
  end
end
