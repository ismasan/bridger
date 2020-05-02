# frozen_string_literal: true

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
      set_access_token Bridger::Auth.config.token_store.set(claims)
    end

    def set_access_token(token)
      @access_token = token
    end

    require 'bootic_client'
    require "bootic_client/strategies/bearer"

    def client
      config = BooticClient::Configuration.new
      config.api_root = 'http://example.org'
      BooticClient::Strategies::Bearer.new(
        config,
        access_token: @access_token.to_s,
        faraday_adapter: [:rack, app]
      )
    end

    def root
      client.root
    end
  end
end
