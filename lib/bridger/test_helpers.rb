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

    def authorize!(claims)
      user_data = claims.delete(:user)
      @access_token = token_generator.generate(claims)
    end

    require 'bootic_client'
    require "bootic_client/strategies/bearer"
    ClientConfig = Struct.new(:api_root)

    def client
      BooticClient::Strategies::Bearer.new(
        ClientConfig.new(
          "http://example.org"
        ),
        access_token: @access_token,
        faraday_adapter: [:rack, app]
      )
    end

    def root
      client.root
    end
  end
end
