require 'openssl'

module Bridger
  module TestHelpers
    def test_private_key
      @test_private_key ||= OpenSSL::PKey::RSA.generate 2048
    end

    def test_public_key
      test_private_key.public_key
    end

    def authorize!(claims)
      @access_token = Bridger::Auth.config.token_store.set(claims)
    end

    require 'bootic_client'
    require "bootic_client/strategies/bearer"
    ClientConfig = Struct.new(:api_root)

    def client
      BooticClient::Strategies::Bearer.new(
        ClientConfig.new(
          "http://example.org"
        ),
        access_token: @access_token.to_s,
        faraday_adapter: [:rack, app]
      )
    end

    def root
      client.root
    end
  end
end
