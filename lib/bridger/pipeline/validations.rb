# frozen_string_literal: true

module Bridger
  class Pipeline
    # Validate query and payload at the top of the pipeline.
    # query_schema and payload_schema are merged from all steps.
    class Validations
      def initialize(schema)
        @schema = schema
      end

      # @param result [Bridger::Result]
      # @return [Bridger::Result]
      def call(result)
        input = result.public_send(key)
        data, errors = resolve_schema(@schema, input)
        if errors.any?
          return result.halt(errors:, key => input).copy do |r|
            r.response.status = 422
          end
        end

        result.continue(key => data)
      end

      private

      def resolve_schema(schema, data)
        resolved = schema.resolve(data)
        [resolved.output, resolved.errors]
      end

      class Query < self
        private def key; :query; end
      end

      class Payload < self
        private def key; :payload; end
      end
    end
  end
end
