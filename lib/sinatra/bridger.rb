require 'bridger'
require 'bridger/default_serializers'
require 'bridger/rack'

module Sinatra
  module Bridger
    class FlushableLogger < SimpleDelegator
      def puts(*args)
        __getobj__.send(:puts, *args)
      end

      def flush

      end
    end

    class SinatraRequestWithParams < SimpleDelegator
      def initialize(request, params)
        super request
        @params = request.params.merge(params)
      end

      def params
        @params
      end
    end

    def bridge(
      service,
      schemas: nil,
      logger: nil,
      not_found_serializer: ::Bridger::DefaultSerializers::NotFound,
      server_error_serializer: ::Bridger::DefaultSerializers::ServerError
    )
      enable :dump_errors
      disable :raise_errors, :show_exceptions, :x_cascade
      if not_found_serializer
        not_found do
          ::Bridger::Rack::ErrorEndpoint.new(settings.service, env['sinatra.error'], not_found_serializer, 404).call(request.env)
        end
      end
      if server_error_serializer
        error do
          ::Bridger::Rack::ErrorEndpoint.new(settings.service, env['sinatra.error'], server_error_serializer, 500).call(request.env)
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
          ::Bridger::Rack::Endpoint.new(settings.service, endpoint).call(SinatraRequestWithParams.new(request, params))
        end
      end

      if schemas
        schemas = '/schemas' if schemas.is_a?(TrueClass)

        get "#{schemas}/?" do
          ::Bridger::Rack::SchemaEndpoint.new(settings.service, settings.service, ::Bridger::DefaultSerializers::Endpoints, 200).call(request.env)
        end

        service.each do |endpoint|
          get "#{schemas}/#{endpoint.name}/?" do
            ::Bridger::Rack::SchemaEndpoint.new(settings.service, endpoint, ::Bridger::DefaultSerializers::Endpoint, 200).call(request.env)
          end
        end
      end
    end
  end
end
