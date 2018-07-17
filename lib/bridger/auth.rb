require "jwt"
require "bridger/scopes"

module Bridger
  class Auth
    AuthError = Class.new(StandardError)
    MissingAccessTokenError = Class.new(AuthError)
    InvalidAccessTokenError = Class.new(AuthError)
    ExpiredAccessTokenError = Class.new(AuthError)
    ForbiddenAccessError    = Class.new(AuthError)
    class InsufficientScopesError < ForbiddenAccessError
      def initialize(required_scope, provided_scopes)
        super "requires scope: #{required_scope}, but provided #{provided_scopes}"
      end
    end

    class Config
      attr_reader :public_key, :algo

      def aliases=(mapping = {})
        @aliases = Scopes::Aliases.new(mapping)
      end

      def aliases
        @aliases ||= Scopes::Aliases.new({})
      end

      def public_key_path=(path)
        @public_key = OpenSSL::PKey::RSA.new(File.read(path))
      end

      def algo=(a)
        @algo = a
      end
    end

    SPACE = /\s+/.freeze
    ALGO = 'RS256'.freeze

    def self.parse(header)
      access_token = header.to_s.split(SPACE).last
      raise MissingAccessTokenError, "missing access token" unless access_token
      new(
        claims: JWT.decode(access_token, config.public_key, true, algorithm: (config.algo || ALGO)).first,
        aliases: config.aliases
      )
    rescue JWT::DecodeError => e
      raise InvalidAccessTokenError.new(e.message)
    rescue JWT::ExpiredSignature => e
      raise ExpiredAccessTokenError.new(e.message)
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
