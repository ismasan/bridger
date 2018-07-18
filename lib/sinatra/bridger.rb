require 'json'
require 'bridger'
require 'bridger/default_serializers'

module Sinatra
  module Bridger
    class LinksHelper
      attr_reader :endpoints, :params

      def initialize(auth, endpoints, app)
        @auth, @endpoints, @app = auth, endpoints, app
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
        halt st, JSON.dump(data.to_hash)
      end

      def serialize(item, serializer)
        serializer.new(item, h: links_helper)
      end

      def auth!
        @auth = ::Bridger::Auth.parse(request)
      end

      def auth
        @auth
      end

      def build_payload
        if request.post? || request.put?
          params.merge(JSON.parse(request.body.read, symbolize_names: true))
        else
          params
        end
      end

      def links_helper
        @links_helper ||= LinksHelper.new(auth, settings.endpoints, self)
      end
    end

    def self.registered(app)
      app.helpers Helpers
    end

    def bridge(endpoints, schemas: false)
      set :endpoints, endpoints

      endpoints.each do |endpoint|
        public_send(endpoint.verb, endpoint.path) do
          begin
            auth! if endpoint.authenticates?
            json endpoint.run!(payload: build_payload, auth: auth, helper: links_helper)
          rescue ::Bridger::MissingAccessTokenError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied), 403
          rescue ::Bridger::ForbiddenAccessError => e
            json serialize(e, ::Bridger::DefaultSerializers::AccessDenied), 403
          rescue ::Bridger::AuthError => e
            json serialize(e, ::Bridger::DefaultSerializers::Unauthorized), 401
          rescue ::Bridger::ValidationErrors => e
            json serialize(e, ::Bridger::DefaultSerializers::InvalidPayload), 422
          end
        end
      end

      if schemas
        get '/schemas' do
          json serialize(endpoints, ::Bridger::DefaultSerializers::Endpoints), 200
        end

        endpoints.each do |en|
          get "/schemas/#{en.name}" do
            json serialize(en, ::Bridger::DefaultSerializers::Endpoint), 200
          end
        end
      end
    end
  end
end
