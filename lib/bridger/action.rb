# frozen_string_literal: true

require "parametric/dsl"

module Bridger
  class Action
    include Parametric::DSL

    def self.payload_schema(*args, &block)
      self.schema *args, &block
    end

    def self.query_schema(*args, &block)
      self.schema *(args.unshift(:query)), &block
    end

    def self.call(result)
      result
    end
  end
end
