# frozen_string_literal: true

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

      def GET
        @params
      end
    end

    def bridge(service, logger: nil)
      enable :dump_errors
      disable :raise_errors, :show_exceptions, :x_cascade
      not_found do
        exception = env['sinatra.error'] || ::Bridger::ResourceNotFoundError.new("Resource not found at '#{env['PATH_INFO']}'")
        settings.service.render_exception(exception, request, status: 404)
      end

      error do
        exception = env['sinatra.error']
        settings.service.render_exception(exception, request, status: 500)
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
          endpoint.to_rack.call(SinatraRequestWithParams.new(request, params))
        end
      end
    end
  end
end
