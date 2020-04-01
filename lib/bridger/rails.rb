raise 'This only works if Rails is installed' unless defined?(ActionDispatch)

require 'rack/common_logger'
require 'bridger/rack'

module Bridger
  module Rails
    if defined?(Devise)
      module ResetDeviseMonkeyPatch
        ORIGINAL_FINALIZE_METHOD = ::ActionDispatch::Routing::RouteSet.instance_method(:finalize!).super_method

        def finalize!
          ORIGINAL_FINALIZE_METHOD.bind(self).call
        end
      end
    else
      module ResetDeviseMonkeyPatch

      end
    end

    def self.router_for(srv, logger: nil)
      ::ActionDispatch::Routing::RouteSet.new.tap do |set|
        set.extend ResetDeviseMonkeyPatch
        set.draw do
          srv.each do |endpoint|
            match endpoint.path, to: ::Bridger::Rails.build_rack_app(srv, endpoint, logger: logger), via: endpoint.verb
          end
          match '*path', to: ::Bridger::Rails.not_found(srv, 404), via: :all
        end
      end
    end

    def self.build_rack_app(srv, endpoint, logger: nil)
      app = Bridger::Rack::EndpointHandler.new(srv, endpoint)
      app = ::Rack::CommonLogger.new(app, logger) if logger
      app
    end

    def self.not_found(srv, status)
      Proc.new do |env|
        path = env['action_dispatch.request.path_parameters'][:path]
        msg = "path #{path} not found"
        ::Bridger::Rack::ErrorHandler.new(
          srv,
          ::Bridger::ResourceNotFoundError.new(msg),
          ::Bridger::DefaultSerializers::NotFound,
          status: 404
        ).call(env)
      end
    end
  end
end
