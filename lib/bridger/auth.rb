require 'logger'
require 'securerandom'
require "bridger/scopes"
require "bridger/errors"

module Bridger
  class Auth
    class HashTokenStore
      def initialize(hash)
        @hash = hash
      end

      def set(claims)
        key = SecureRandom.hex
        @hash[key] = claims.each_with_object({}){|(k,v), h| h[k.to_s] = v}
        key
      end

      def get(key)
        @hash[key]
      end
    end

    class Config
      attr_reader :aliases, :public_key, :algo, :token_store, :parse_values, :logger

      def initialize
        @parse_values = [:header, 'HTTP_AUTHORIZATION']
        @aliases = Scopes::Aliases.new({})
        @logger = Logger.new(IO::NULL)
        self.token_store = {}
      end

      def aliases=(mapping = {})
        @aliases = Scopes::Aliases.new(mapping)
      end

      def logger=(l)
        @logger = l
      end

      def rsa_key=(key)
        require 'bridger/jwt_token_store'
        key, pkey = if key.respond_to?(:public_key)
                      [key.public_key, key]
                    else
                      [key, nil]
                    end
        self.token_store = JWTTokenStore.new(key, pkey: pkey)
      end

      def token_store=(st)
        st = HashTokenStore.new(st) if st.is_a?(Hash)
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

      raise MissingAccessTokenError, "missing access token with #{config.parse_values.last} in #{config.parse_values.first}" unless access_token
      claims = config.token_store.get(access_token)
      raise InvalidAccessTokenError, "unknown access token" unless claims

      new(
        access_token: access_token,
        claims: claims,
        aliases: config.aliases,
      )
    rescue StandardError => e
      config.logger.error "#{e.class.name}: #{e.message}"
      raise
    end

    def self.config(&block)
      @config ||= Config.new

      if block_given?
        yield @config
      end

      @config
    end

    attr_reader :access_token, :claims, :scopes

    def initialize(access_token: nil, claims: {}, aliases: self.config.aliases)
      @access_token = access_token
      @claims = claims
      @scopes = Scopes.new(aliases.map(@claims["scopes"]))
    end

    def authorized?(scope)
      return true if scope.nil?
      scopes.can? scope
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
