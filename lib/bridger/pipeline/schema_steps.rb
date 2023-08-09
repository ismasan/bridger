# frozen_string_literal: true

module Bridger
  class Pipeline
    class SchemaSteps
      # Register #query_schema and #payload_schema methods on the pipeline
      # #call is a NOOP
      #
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
        input, result = raw_input_for(result, key)
        data, errors = resolve_schema(schema, input)
        merged_input = (result.public_send(key) || {}).merge(data.to_h)
        if errors.any?
          return result.halt(status: 422, errors:, key => merged_input)
        end

        result.continue(key => merged_input)
      end

      private

      attr_reader :schema

      def resolve_schema(schema, data)
        resolved = schema.resolve(data)
        [resolved.output, resolved.errors]
      end

      def raw_input_for(result, key)
        if (input = result.context.dig(:__raw_inputs, key))
          [input, result]
        else
          input = result.public_send(key)
          result = result.copy do |r|
            r.context[:__raw_inputs] ||= {}
            r.context[:__raw_inputs][key] = input
          end
          [input, result]
        end
      end

      class Query < self
        def query_schema; schema; end
        private def key; :query; end
      end

      class Payload < self
        def payload_schema; schema; end
        private def key; :payload; end
      end
    end
  end
end
