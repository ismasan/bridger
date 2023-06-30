# frozen_string_literal: true

module Bridger
  module DefaultActions
    class PassThrough
      attr_reader :query_schema, :payload_schema

      def initialize(data = {})
        @data = data
        @query_schema = Parametric::Schema.new
        @payload_schema = Parametric::Schema.new
      end

      def call(result)
        result.continue(data: @data)
      end
    end

    class Schema
      attr_reader :query_schema, :payload_schema

      def initialize(service)
        @service = service
        @query_schema = Parametric::Schema.new do
          field(:rel).type(:string).present
        end
        @payload_schema = Parametric::Schema.new
      end

      def call(result)
        endpoint = @service[result.query[:rel].to_sym]
        result.continue(data: { endpoint: })
      end
    end
  end
end
