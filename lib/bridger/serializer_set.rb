# frozen_string_literal: true

require 'bridger/default_serializers'
require 'bridger/request_helper'

module Bridger
  class SerializerSet
    Record = Data.define(:status, :serializer)

    class Stack
      attr_reader :to_a

      def initialize
        @to_a = []
      end

      def on(status, serializer)
        @to_a << Record.new(status:, serializer:)
        self
      end
    end

    def self.build(&block)
      new.build_for(&block)
    end

    attr_reader :serializers

    def initialize(serializers = [])
      @serializers = serializers
    end

    def build_for(&block)
      stack = Stack.new
      yield stack if block_given?
      self.class.new(stack.to_a + serializers).freeze
    end

    def run(result, service:, rel_name: nil)
      record = serializers.find { |record| record.status === result.response.status }
      serializer = record ? record.serializer : DefaultSerializers::Success
      helper = Bridger::RequestHelper.new(
        service,
        result.request,
        params: result.query,
        rel_name:
      )
      output = serializer.call(result, auth: result.auth, h: helper)
      # TODO: content negotiation.
      # different serializers for different content types.
      result.copy do |r|
        r.response.set_header('Content-Type', 'application/json')
        r.response.write(JSON.dump(output))
      end
    end

    DEFAULT = build do |set|
      set.on(204, DefaultSerializers::NoContent)
      set.on(200..299, DefaultSerializers::Success)
      set.on(304, DefaultSerializers::NoContent)
      set.on(401, DefaultSerializers::Unauthorized)
      set.on(403, DefaultSerializers::AccessDenied)
      set.on(404, DefaultSerializers::NotFound)
      set.on(412, DefaultSerializers::NoContent)
      set.on(422, DefaultSerializers::InvalidPayload)
      set.on(429, DefaultSerializers::TooManyRequests)
      set.on(500, DefaultSerializers::ServerError)
    end
  end
end
