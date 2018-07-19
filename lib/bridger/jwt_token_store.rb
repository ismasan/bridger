require "jwt"
require "openssl"
require 'securerandom'
require 'pathname'
require "bridger/errors"

module Bridger
  class JWTTokenStore
    ALGO = 'RS256'.freeze
    WINDOW = 10 # seconds

    def initialize(key, pkey: nil, algo: ALGO)
      @algo = algo
      @public_key = rsa_key(key)
      @private_key = pkey ? rsa_key(pkey) : nil
    end

    def set(claims)
      now = Time.now.utc.to_i
      claims = {
        exp: now + WINDOW,
        iat: now,
        jti: SecureRandom.hex(7)
      }.merge(claims)

      JWT.encode(claims, private_key, algo)
    end

    def get(token)
      JWT.decode(token, public_key, true, algorithm: algo).first
    rescue JWT::ExpiredSignature => e
      raise ExpiredAccessTokenError.new(e.message)
    rescue JWT::DecodeError => e
      raise InvalidAccessTokenError.new(e.message)
    end

    private
    attr_reader :public_key, :private_key, :algo

    def rsa_key(key)
      case key
      when Pathname
        OpenSSL::PKey::RSA.new(key.read)
      when String
        OpenSSL::PKey::RSA.new(key)
      when OpenSSL::PKey::RSA
        key
      else
        raise "key #{key} must be a Pathname, string or an OpenSSL::PKey::RSA"
      end
    end
  end
end
