# frozen_string_literal: true

module Bridger
  class Pipeline
    class ParsePayloadStep
      JSON_MIME = 'application/json'

      PARSERS = {
        JSON_MIME => ->(payload) { JSON.parse(payload, symbolize_names: true) },
      }

      def call(result)
        parser = PARSERS.fetch(result.request.media_type) do
          PARSERS.fetch(JSON_MIME)
        end

        payload = parser.call(result.request.body.read)
        result.continue(payload:)
      end
    end
  end
end
