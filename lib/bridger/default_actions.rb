module Bridger
  module DefaultActions
    class PassThrough
      attr_reader :query_schema, :payload_schema

      def initialize(object)
        @object = object
        @query_schema = Parametric::Schema.new
        @payload_schema = Parametric::Schema.new
      end

      def call(*_)
        @object
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

      def call(query: {}, payload: {}, auth: nil)
        @service[query[:rel].to_sym]
      end
    end
  end
end
