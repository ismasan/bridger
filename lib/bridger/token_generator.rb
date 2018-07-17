require 'jwt'
require 'openssl'
require 'securerandom'

module Bridger
  class TokenGenerator
    ALGO = 'RS256'.freeze

    def initialize(private_key_path)
      @private_key = OpenSSL::PKey::RSA.new(
        File.read(private_key_path)
      )
    end

    def generate(claims)
      claims = {
        exp: Time.now.to_i + 3600,
        iat: Time.now.to_i,
        jti: SecureRandom.hex(7)
      }.merge(claims)

      JWT.encode(claims, @private_key, ALGO)
    end
  end
end
