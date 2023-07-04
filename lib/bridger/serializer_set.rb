# frozen_string_literal: true

require 'bridger/default_serializers'
require 'bridger/request_helper'

module Bridger
  class SerializerSet
    Record = Data.define(:status, :serializer)

    def self.build(&block)
      new.build_for(&block)
    end

    attr_reader :serializers

    class Top
      def self.resolve(result)
        nil
      end
    end

    def initialize(parent = Top)
      @parent = parent
      @serializers = []
    end

    # extend
    def build_for(&block)
      child = self.class.new(self)
      yield child if block_given?
      child
    end

    def on(status, serializer = nil, &block)
      serializer ||= block
      raise ArgumentError, 'serializer must be a callable' unless serializer.respond_to?(:call)

      @serializers << Record.new(status:, serializer:)
      self
    end

    def resolve(result)
      serializers.find { |record| record.status === result.response.status } || @parent.resolve(result)
    end

    def run(result, service:, rel_name: nil)
      record = resolve(result)
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
      set.on(200..299, DefaultSerializers::Success) # <- catch all
      set.on(304, DefaultSerializers::NoContent)
      set.on((300..399), DefaultSerializers::NoContent) # <- catch all
      set.on(401, DefaultSerializers::Unauthorized)
      set.on(403, DefaultSerializers::AccessDenied)
      set.on(404, DefaultSerializers::NotFound)
      set.on(412, DefaultSerializers::NoContent)
      set.on(422, DefaultSerializers::InvalidPayload)
      set.on(429, DefaultSerializers::TooManyRequests)
      set.on((400..499), DefaultSerializers::NoContent) # <- catch all
      set.on((500..511), DefaultSerializers::ServerError) # <- catch all
    end
  end
end
