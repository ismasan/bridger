require 'json'
require 'bridger'
require 'bridger/default_serializers'

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
      attr_reader :rel_name, :params, :endpoints

      def initialize(auth, endpoints, app, rel_name: nil)
        @auth, @rel_name, @endpoints, @app = auth, rel_name, endpoints, app
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
        @auth
      end

      def build_payload
        if request.post? || request.put?
          JSON.parse(request.body.read, symbolize_names: true)
        else
          {}
        end
      end

      def request_helper
        RequestHelper.new(auth, settings.endpoints, self)
      end
    end

    def bridge(endpoints, schemas: false, logger: nil)
      helpers Helpers
      enable :dump_errors
      disable :raise_errors, :show_exceptions
      not_found do
        json serialize(env['sinatra.error'], ::Bridger::DefaultSerializers::NotFound), 404
      end
      error do
        json serialize(env['sinatra.error'], ::Bridger::DefaultSerializers::ServerError), 500
      end

      set :endpoints, endpoints

      if logger
        logger = FlushableLogger.new(logger)

        configure do
          use ::Rack::CommonLogger, logger
        end

        before do
          env['rack.errors'] = logger
        end
      end

      endpoints.each do |endpoint|
        public_send(endpoint.verb, endpoint.path) do
          helper = RequestHelper.new(auth, settings.endpoints, self, rel_name: endpoint.name)
          begin
            auth! if endpoint.authenticates?
            json endpoint.run!(query: params, payload: build_payload, auth: auth, helper: helper)
          rescue ::Bridger::MissingAccessTokenError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
          rescue ::Bridger::ForbiddenAccessError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
          rescue ::Bridger::AuthError => e
            json serialize(e, ::Bridger::DefaultSerializers::Unauthorized, helper: helper), 401
          rescue ::Bridger::ValidationErrors => e
            json serialize(e, ::Bridger::DefaultSerializers::InvalidPayload, helper: helper), 422
          end
        end
      end

      if schemas
        get '/schemas/?' do
          json serialize(endpoints, ::Bridger::DefaultSerializers::Endpoints), 200
        end

        endpoints.each do |en|
          get "/schemas/#{en.name}/?" do
            json serialize(en, ::Bridger::DefaultSerializers::Endpoint), 200
          end
        end
      end
    end
  end
end
