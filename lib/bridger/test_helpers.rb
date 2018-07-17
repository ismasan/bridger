require 'openssl'
require "bridger/token_generator"

module Bridger
  module TestHelpers
    def test_private_key
      @test_private_key ||= OpenSSL::PKey::RSA.generate 2048
    end

    def test_public_key
      test_private_key.public_key
    end

    def token_generator
      @token_generator ||= Bridger::TokenGenerator.new(test_private_key)
    end
  end
end
