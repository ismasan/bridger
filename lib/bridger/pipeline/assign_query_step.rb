# frozen_string_literal: true

module Bridger
  class Pipeline
    class AssignQueryStep
      def self.call(result)
        query = symbolize(result.request.GET)

        if upstream_params = result.request.env['action_dispatch.request.path_parameters']
          query.merge!(symbolize(upstream_params))
        end

        result.continue(query:)
      end

      def self.symbolize(hash)
        return hash unless hash.is_a?(Hash)

        hash.each.with_object({}) do |(k, v), h|
          h[k.to_sym] = case v
                        when Hash
                          symbolize(v)
                        when Array
                          v.map { |e| symbolize(e) }
                        else
                          v
                        end
        end
      end
    end
  end
end
