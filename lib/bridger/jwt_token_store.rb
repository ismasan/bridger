require "jwt"
require "openssl"
require 'securerandom'
require "bridger/errors"

module Bridger
  class JWTTokenStore
    RSA_ALGOS = ['RS256', 'RS384', 'RS512'].freeze
    WINDOW = 10 # seconds

    def initialize(key, pkey: nil, algo: RSA_ALGOS.first)
      @algo = algo
      if RSA_ALGOS.include?(algo)
        @public_key = rsa_key(key)
        @private_key = pkey ? rsa_key(pkey) : nil
      else
        @public_key = @private_key = read_key(key)
        raise ArgumentError, "key must respond to #read or be a String, was #{key.inspect}" unless @public_key
      end
    end

    def set(claims)
      raise ArgumentError, "you need to provide a valid #{algo} key in order to generate JWT tokens" unless private_key

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

    def read_key(key)
      if key.respond_to?(:read)
        key.read
      elsif key.is_a?(String)
        key
      else
        nil
      end
    end

    def rsa_key(key)
      if txt = read_key(key)
        OpenSSL::PKey::RSA.new(txt)
      elsif key.is_a?(OpenSSL::PKey::RSA)
        key
      else
        raise ArgumentError, "key #{key} must respond to #read, be a string or an OpenSSL::PKey::RSA"
      end
    end
  end
end
