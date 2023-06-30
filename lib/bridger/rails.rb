# frozen_string_literal: true

raise 'This only works if Rails is installed' unless defined?(ActionDispatch)

require 'rack/common_logger'

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
      app = endpoint.to_rack
      app = ::Rack::CommonLogger.new(app, logger) if logger
      app
    end

    def self.not_found(srv, status)
      proc do |env|
        path = env['action_dispatch.request.path_parameters'][:path]
        exception = ::Bridger::ResourceNotFoundError.new("path #{path} not found")
        request = ::Rack::Request.new(env)
        srv.render_exception(exception, request, status:)
      end
    end
  end
end
