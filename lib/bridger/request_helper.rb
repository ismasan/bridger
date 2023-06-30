# frozen_string_literal: true

module Bridger
  class RequestHelper
    HTTP_X_FORWARDED_HOST = 'HTTP_X_FORWARDED_HOST'

    attr_reader :rel_name, :params, :service

    def initialize(service, request, params: {}, rel_name: nil)
      @service = service
      @request = request
      @params = params
      @rel_name = rel_name
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

    def forwarded?(req)
      req.env.include? HTTP_X_FORWARDED_HOST
    end
  end
end
