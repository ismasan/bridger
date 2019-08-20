module Bridger
  class JsonSchemaGenerator
    BASE = {
      '$schema' => 'http://json-schema.org/draft-04/schema#',
      'type' => 'object'
    }.freeze

    MissingType = Class.new(StandardError)

    def self.generate(schema)
      new(schema).generate
    end

    def initialize(schema)
      @schema = schema
    end

    def generate
      BASE.merge(process(schema.structure))
    end

    private

    attr_reader :schema

    def process(structure)
      reqs = []
      structure.each.with_object({'properties' => {}}) do |(k, attrs), node|
        unless attrs[:type]
          raise MissingType.new("Missing type field for property '#{k}'")
        end
        base = {'type' => attrs[:type].to_s}

        base['enum'] = attrs[:options] if attrs[:options]
        base['title'] = attrs[:title] if attrs[:title]
        base['description'] = attrs[:description] if attrs[:description]
        base['default'] = attrs[:default] if attrs[:default] && !attrs[:default].respond_to?(:call)
        base['example'] = attrs[:example] if attrs[:example]
        reqs << k.to_s if attrs[:required]

        if attrs[:structure]
          if base['type'] == 'array' # array of objects
            base['items'] = {'type' => 'object'}.merge(process(attrs[:structure]))
          else
            base.merge!(process(attrs[:structure]))
          end
        end

        node['properties'][k.to_s] = base
        node['required'] = reqs if reqs.any?
      end
    end
  end
end
