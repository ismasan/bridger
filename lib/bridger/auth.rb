require "jwt"
require "openssl"
require "bridger/scopes"

module Bridger
  class Auth
    AuthError = Class.new(StandardError)
    MissingAccessTokenError = Class.new(AuthError)
    MissingPublicKeyError = Class.new(AuthError)
    InvalidAccessTokenError = Class.new(AuthError)
    ExpiredAccessTokenError = Class.new(AuthError)
    ForbiddenAccessError    = Class.new(AuthError)
    class InsufficientScopesError < ForbiddenAccessError
      def initialize(required_scope, provided_scopes)
        super "requires scope: #{required_scope}, but provided #{provided_scopes}"
      end
    end

    class JWTTokenStore
      ALGO = 'RS256'.freeze

      def initialize(key, algo: ALGO)
        @algo = algo
        @public_key = if key.is_a?(String)
          OpenSSL::PKey::RSA.new(File.read(key))
        else
          key
        end
      end

      def [](token)
        JWT.decode(token, public_key, true, algorithm: algo).first
      rescue JWT::DecodeError => e
        raise InvalidAccessTokenError.new(e.message)
      rescue JWT::ExpiredSignature => e
        raise ExpiredAccessTokenError.new(e.message)
      end

      private
      attr_reader :public_key, :algo
    end

    class Config
      attr_reader :public_key, :algo, :token_store, :parse_values

      def initialize
        @token_store = {}
        @parse_values = [:header, 'HTTP_AUTHORIZATION']
      end

      def aliases=(mapping = {})
        @aliases = Scopes::Aliases.new(mapping)
      end

      def aliases
        @aliases ||= Scopes::Aliases.new({})
      end

      def public_key=(key)
        @token_store = JWTTokenStore.new(key)
      end

      def token_store=(st)
        @token_store = st
      end

      def parse_from(strategy, field_name)
        @parse_values = [strategy, field_name]
      end
    end

    SPACE = /\s+/.freeze

    def self.parse(request, config = self.config)
      access_token = case config.parse_values.first
      when :header
        request.env[config.parse_values.last].to_s.split(SPACE).last
      when :query
        request.params[config.parse_values.last.to_s]
      else
        nil
      end

      raise MissingAccessTokenError, "missing access token" unless access_token
      claims = config.token_store[access_token]
      raise InvalidAccessTokenError, "unknown access token" unless claims

      new(
        claims: claims,
        aliases: config.aliases,
      )
    end

    def self.config(&block)
      @config ||= Config.new

      if block_given?
        yield @config
      end

      @config
    end

    attr_reader :claims, :shop_ids, :app_id, :user_id, :account_id, :scopes

    def initialize(claims: {}, aliases: self.config.aliases)
      @claims = claims
      @shop_ids = @claims["sids"] || []
      @app_id = @claims["aid"]
      @user_id = @claims["uid"]
      @account_id = @claims["aid"]
      @scopes = Scopes.new(aliases.map(@claims["scopes"]))
    end

    def has_user?
      user_id.to_i != 0
    end

    def authorize!(required_scope, authorizer, *args)
      sp = scopes.resolve(required_scope)
      if !sp
        raise InsufficientScopesError.new(required_scope, scopes)
      elsif !authorizer.authorized?(sp, self, *args)
        raise ForbiddenAccessError.new("no permissions to access this resource")
      end

      true
    end
  end
end
