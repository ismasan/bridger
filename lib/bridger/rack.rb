require 'rack'
require 'multi_json'
require 'parametric/struct'
require 'bridger'
require 'bridger/default_serializers'

module Bridger
  module Rack
    module HandlerUtils
      private

      def json(data, st = 200)
        heads = { 'Content-Type' => 'application/json' }
        if data
          [st, heads, [MultiJson.dump(data.to_hash)]]
        else
          [204, heads, ["{}"]]
        end
      end

      def serialize(item, serializer, helper: request_helper)
        serializer.new(item, h: helper)
      end

      def build_request(env_or_req)
        env_or_req = ::Rack::Request.new(env_or_req) if env_or_req.kind_of?(Hash)
        env_or_req
      end
    end

    class ErrorHandler
      include HandlerUtils

      def initialize(service, error, serializer, status: 200)
        @service = service
        @error, @serializer, @status = error, serializer, status
      end

      def call(env)
        request = build_request(env)
        helper = RequestHelper.new(service, request)
        json serializer.new(error, h: helper), status
      end

      private

      attr_reader :service, :error, :serializer, :status
    end

    class EndpointHandler
      include HandlerUtils

      def initialize(service, endpoint)
        @service = service
        @endpoint = endpoint
        @request = nil
      end

      def call(env)
        @request = build_request(env)
        helper = RequestHelper.new(service, @request, rel_name: endpoint.name)
        begin
          auth! if endpoint.authenticates?
          json endpoint.run!(query: helper.params, payload: build_payload, auth: auth, helper: helper)
        rescue ::Bridger::MissingAccessTokenError => e
          json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
        rescue ::Bridger::ForbiddenAccessError => e
          json serialize(e, ::Bridger::DefaultSerializers::AccessDenied, helper: helper), 403
        rescue ::Bridger::AuthError => e
          json serialize(e, ::Bridger::DefaultSerializers::Unauthorized, helper: helper), 401
        rescue ::Bridger::ValidationErrors, Parametric::InvalidStructError => e
          json serialize(e, ::Bridger::DefaultSerializers::InvalidPayload, helper: helper), 422
        rescue ::Bridger::ResourceNotFoundError => e
          json serialize(e, ::Bridger::DefaultSerializers::NotFound, helper: helper), 404
        end
      end

      def inspect
        %(<#{self.class} [#{endpoint.name}] #{endpoint.verb} #{endpoint.path}>)
      end

      private

      attr_reader :service, :endpoint, :request

      def auth!
        @auth = ::Bridger::Auth.parse(request)
      end

      def auth
        @auth ||= ::Bridger::NoopAuth
      end

      def build_payload
        if request.post? || request.put?
          MultiJson.load(request.body.read, symbolize_keys: true)
        else
          {}
        end
      end
    end

    class RequestHelper
      HTTP_X_FORWARDED_HOST = 'HTTP_X_FORWARDED_HOST'.freeze

      attr_reader :rel_name, :params, :service

      def initialize(service, request, rel_name: nil)
        @rel_name, @service, @request = rel_name, service, request
      end

      def params
        @params ||= (
          upstream_params = request.env['action_dispatch.request.path_parameters'] || {}
          symbolize(request.params).merge(symbolize(upstream_params))
        )
      end

      def url(path = nil)
        uri = [host = String.new]
        host << "http#{'s' if request.ssl?}://"
        if forwarded?(request) or request.port != (request.ssl? ? 443 : 80)
          host << request.host_with_port
        else
          host << request.host
        end
        uri << request.script_name.to_s
        uri << (path ? path : request.path_info).to_s
        File.join uri
      end

      def current_url
        url
      end

      private

      attr_reader :request

      def symbolize(hash)
        hash.each.with_object({}) do |(k, v), h|
          h[k.to_sym] = v
        end
      end

      def forwarded?(req)
        req.env.include? HTTP_X_FORWARDED_HOST
      end
    end
  end
end
