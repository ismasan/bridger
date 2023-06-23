# frozen_string_literal: true

require 'logger'
require 'securerandom'
require "bridger/scopes"
require "bridger/errors"
require "bridger/authenticators"

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
      attr_reader :aliases, :token_store, :logger

      def initialize
        @aliases = Scopes::Aliases.new({})
        @logger = Logger.new(IO::NULL)
        @authenticator = Authenticators::RequestHeader.new('HTTP_AUTHORIZATION')
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

      def authenticator(callable = nil, &block)
        callable ||= block
        return @authenticator unless callable

        @authenticator = callable
      end

      def authenticator=(callable)
        authenticator(callable)
      end

      def parse_from(strategy, field_name)
        logger.warn '[DEPRECATED] #parse_from is deprecated. Use #authenticate instead'
        callable = case strategy
        when :header
          Authenticators::RequestHeader.new(field_name)
        when :query
          Authenticators::RequestQuery.new(field_name)
        else
          raise ArgumentError, "unknown authenticator: #{strategy}"
        end

        authenticator(callable)
      end
    end

    def self.parse(request, config = self.config)
      access_token = config.authenticator.call(request)

      raise MissingAccessTokenError, "missing access token with #{config.authenticator}" unless access_token

      resolve_access_token(access_token, config)
    rescue StandardError => e
      config.logger.error "#{e.class.name}: #{e.message}"
      raise
    end

    def self.resolve_access_token(access_token, config = self.config)
      claims = config.token_store.get(access_token)
      raise InvalidAccessTokenError, 'unknown access token' unless claims

      new(
        access_token: access_token,
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

    attr_reader :access_token, :claims, :scopes

    # @option access_token [String] the access token. Default: nil
    # @option claims [Hash] the claims of the access token.
    # @option aliases [Scopes::Aliases]
    def initialize(access_token: nil, claims: {}, aliases: self.config.aliases)
      @access_token = access_token
      @claims = claims
      @scopes = aliases.map(@claims['scopes'])
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

  class NoopAuth
    def self.authorized?(_scope)
      true
    end

    def self.authorize!(*_args)
      true
    end
  end
end
