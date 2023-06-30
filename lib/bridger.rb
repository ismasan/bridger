# frozen_string_literal: true

require 'multi_json'
require 'bridger/version'

module Bridger
  class NullInstrumenter
    def self.instrument(_name, _payload = {}, &_block)
      yield
    end
  end

  class TestInstrumenter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def instrument(name, payload = {}, &_block)
      self.calls << [name, payload]
      yield
    end
  end
end

require 'bridger/auth'
require 'bridger/service'
require 'bridger/action'
require 'bridger/serializer'
