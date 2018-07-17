require 'jwt'
require 'openssl'
require 'securerandom'

module Bridger
  class TokenGenerator
    ALGO = 'RS256'.freeze

    def initialize(private_key, algo: ALGO)
      @private_key = if private_key.is_a?(String)
        OpenSSL::PKey::RSA.new(File.read(private_key))
      else
        private_key
      end
      @algo = algo
    end

    def generate(claims)
      claims = {
        exp: Time.now.to_i + 3600,
        iat: Time.now.to_i,
        jti: SecureRandom.hex(7)
      }.merge(claims)

      JWT.encode(claims, @private_key, @algo)
    end
  end
end
