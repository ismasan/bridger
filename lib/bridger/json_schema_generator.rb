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
      BASE.merge(process(schema.structure))
    end

    private

    attr_reader :schema

    def process(structure)
      props = {}
      required = []
      structure.each do |(k,v)|
        unless v[:type]
          raise MissingType.new("Missing type field for property '#{k}'")
        end

        base = { 'type' => v[:type].to_s }

        props[k.to_s] = if v[:structure]
          base.merge(process(v[:structure]))
        else
          base.tap do |properties|
            properties["enum"] = v[:options] if v[:options]
            properties["description"] = v[:description] if v[:description]
            properties["default"] = v[:default] if v[:default] && !v[:default].respond_to?(:call)
            properties["example"] = v[:example] if v[:example]
          end
        end

        if v[:required]
          required << k.to_s
        end
      end

      {
        'type' => 'object',
        'properties' => props,
        'required' => required
      }
    end
  end
end
