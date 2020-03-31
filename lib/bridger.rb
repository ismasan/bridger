require 'multi_json'
require 'bridger/version'

module Bridger
  class NullInstrumenter
    def self.instrument(_name, _payload = {}, &_block)
      yield
    end
  end
end

require 'bridger/auth'
require 'bridger/service'
require 'bridger/action'
require 'bridger/serializer'
