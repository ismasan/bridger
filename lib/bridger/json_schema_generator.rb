module Bridger
  class JsonSchemaGenerator
    BASE = {
      "$schema" => "http://json-schema.org/draft-04/schema#",
    }.freeze

    MissingType = Class.new(StandardError)

    def initialize(schema)
      @schema = schema
    end

    def generate
      output = BASE.dup
      output["type"] = "object"
      output["properties"] = process(schema.structure)
      output
    end

    private

    attr_reader :schema

    def process(structure)
      structure.each_with_object({}) do |(k,v), memo|
        unless v[:type]
          raise MissingType.new("Missing type field for property '#{k}'")
        end

        base = { "type" => v[:type].to_s }

        memo[k.to_s] = if v[:structure]
          base.merge("properties" => process(v[:structure]))
        else
          base.tap do |properties|
            properties["enum"] = v[:options] if v[:options]
            properties["description"] = v[:description] if v[:description]
            properties["default"] = v[:default] if v[:default]
            properties["example"] = v[:example] if v[:example]
          end
        end

        if v[:required]
          (memo["required"] ||= []) << k.to_s
        end
      end
    end
  end
end
