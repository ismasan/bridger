# frozen_string_literal: true

require 'bridger/default_serializers'
require 'bridger/request_helper'

module Bridger
  class SerializerSet
    Record = Data.define(:status, :serializer)

    attr_reader :serializers

    def initialize(serializers = [])
      @serializers = serializers
    end

    def build_for(&block)
      instance = self.class.new(serializers.dup)
      yield instance if block_given?
      instance.freeze
    end

    def on(status, serializer)
      @serializers << Record.new(status:, serializer:)
      self
    end

    def run(result, service:, rel_name:)
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

    DEFAULT = new.tap do |set|
      set.on(204, DefaultSerializers::NoContent)
      set.on(200..299, DefaultSerializers::Success)
      set.on(422, DefaultSerializers::InvalidPayload)
      set.on(401, DefaultSerializers::Unauthorized)
      set.on(403, DefaultSerializers::AccessDenied)
      set.on(404, DefaultSerializers::NotFound)
      set.on(500, DefaultSerializers::ServerError)
      set.freeze
    end
  end
end
