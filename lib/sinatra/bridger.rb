require 'json'
require 'bridger'
require 'bridger/default_serializers'
require 'parametric/struct'

module Sinatra
  module Bridger
    class FlushableLogger < SimpleDelegator
      def puts(*args)
        __getobj__.send(:puts, *args)
      end

      def flush

      end
    end

    class RequestHelper
      attr_reader :rel_name, :params, :service

      def initialize(auth, service, app, rel_name: nil)
        @auth, @rel_name, @service, @app = auth, rel_name, service, app
        @request = app.request
        @params = app.params
      end

      def url(path)
        @app.url(path)
      end

      def current_url
        @request.url
      end
    end

    module Helpers
      def json(data, st = 200)
        content_type "application/json"
        if data
          halt st, ::JSON.generate(data.to_hash)
        else
          halt 204, "{}"
        end
      end

      def serialize(item, serializer, helper: request_helper)
        serializer.new(item, h: helper)
      end

      def auth!
        @auth = ::Bridger::Auth.parse(request)
      end

      def auth
        @auth ||= ::Bridger::NoopAuth
      end

      def build_payload
        if request.post? || request.put?
          JSON.parse(request.body.read, symbolize_names: true)
        else
          {}
        end
      end

      def request_helper
        RequestHelper.new(auth, settings.service, self)
      end
    end

    def bridge(
      service,
      schemas: nil,
      logger: nil,
      not_found_serializer: ::Bridger::DefaultSerializers::NotFound,
      server_error_serializer: ::Bridger::DefaultSerializers::ServerError
    )
      helpers Helpers
      enable :dump_errors
      disable :raise_errors, :show_exceptions
      if not_found_serializer
        not_found do
          json serialize(env['sinatra.error'], not_found_serializer), 404
        end
      end
      if server_error_serializer
        error do
          json serialize(env['sinatra.error'], server_error_serializer), 500
        end
      end

      set :service, service

      if logger
        logger = FlushableLogger.new(logger)

        configure do
          use ::Rack::CommonLogger, logger
        end

        before do
          env['rack.errors'] = logger
        end
      end

      service.each do |endpoint|
        public_send(endpoint.verb, endpoint.path) do
          helper = RequestHelper.new(auth, settings.service, self, rel_name: endpoint.name)
          begin
            auth! if endpoint.authenticates?
            json endpoint.run!(query: params, payload: build_payload, auth: auth, helper: helper)
          rescue ::Bridger::MissingAccessTokenError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
          rescue ::Bridger::ForbiddenAccessError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
          rescue ::Bridger::AuthError => e
            json serialize(e, ::Bridger::DefaultSerializers::Unauthorized, helper: helper), 401
          rescue ::Bridger::ValidationErrors, Parametric::InvalidStructError => e
            json serialize(e, ::Bridger::DefaultSerializers::InvalidPayload, helper: helper), 422
          end
        end
      end

      if schemas
        schemas = '/schemas' if schemas.is_a?(TrueClass)

        get "#{schemas}/?" do
          json serialize(service, ::Bridger::DefaultSerializers::Endpoints), 200
        end

        service.each do |en|
          get "#{schemas}/#{en.name}/?" do
            json serialize(en, ::Bridger::DefaultSerializers::Endpoint), 200
          end
        end
      end
    end
  end
end
