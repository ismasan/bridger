module Bridger
  ResourceNotFoundError = Class.new(StandardError)
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
end
