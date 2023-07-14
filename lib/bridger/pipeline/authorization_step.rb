# frozen_string_literal: true

require 'bridger/auth'

module Bridger
  class Pipeline
    class AuthorizationStep
      # @param auth_config [Bridger::Auth::Config]
      # @param scope [Bridger::Scopes::Scope]
      def initialize(auth_config, scope)
        @auth_config = auth_config
        @scope = scope
      end

      # @param result [Bridger::Result]
      # @return [Bridger::Result]
      def call(result)
        access_token = @auth_config.authenticator.call(result.request)
        return result.halt(status: 401) unless access_token

        claims = @auth_config.token_store.get(access_token)
        return result.halt(status: 401) unless claims

        auth = Bridger::Auth.new(
          access_token:,
          claims:,
          aliases: @auth_config.aliases,
        )
        return result.halt(status: 403) unless auth.authorized?(@scope)

        result.continue(auth:)
      rescue Bridger::InvalidAccessTokenError, Bridger::ExpiredAccessTokenError
        # TODO: log error
        result.halt(status: 401)
      end
    end
  end
end
