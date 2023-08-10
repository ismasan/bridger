# frozen_string_literal: true

require 'spec_helper'
require 'bridger/json_schema_generator'

RSpec.describe Bridger::JsonSchemaGenerator do
  let(:s1) do
    Parametric::Schema.new do |sc, _|
      sc.field(:name).type(:string).meta(title: 'Some title', tags: ['t1', 't2']).present
      sc.field(:age).type(:integer).required.default(41)
      sc.field(:letters).type(:string).options(['A', 'B'])
      sc.field(:friends).type(:array).schema do
        field(:name).type(:string).meta(title: 'Some other title', description: 'Some description', foo: 'bar').present
      end
      sc.field(:company).type(:object).schema do
        field(:name).type(:string).present
      end
      sc.field(:entity_type).type(:string).required
      sc.field(:entity).type(:object).tagged_one_of do |sub|
        sub.index_by(:entity_type)
        sub.on('person', person_schema)
        sub.on('company', company_schema)
      end
    end
  end

  let(:person_schema) do
    Parametric::Schema.new do
      field(:name).type(:string).present
      field(:age).type(:integer).present
    end
  end

  let(:company_schema) do
    Parametric::Schema.new do
      field(:name).type(:string).present
      field(:reg_code).type(:string).present
    end
  end

  it 'serializes structure correctly' do
    result = described_class.generate(s1)
    expect(result['$schema']).to eq 'http://json-schema.org/draft-04/schema#'
    expect(result['type']).to eq 'object'
    result['properties'].tap do |props|
      expect(props['name']['type']).to eq 'string'
      expect(props['name']['title']).to eq 'Some title'
      expect(props['name']['tags']).to eq ['t1', 't2']
      expect(props['age']['type']).to eq 'integer'
      expect(props['age']['default']).to eq 41
      expect(props['letters']['type']).to eq 'string'
      expect(props['letters']['enum']).to eq ['A', 'B']
      expect(props['company']['type']).to eq 'object'
      props['company']['properties'].tap do |company|
        expect(company['name']['type']).to eq 'string'
      end
      expect(props['company']['required']).to eq ['name']

      expect(props['friends']['type']).to eq 'array'
      props.dig('friends', 'items', 'properties', 'name').tap do |name|
        expect(name['title']).to eq 'Some other title'
        expect(name['description']).to eq 'Some description'
        expect(name['foo']).to eq 'bar'
      end
      props.dig('entity').tap do |entity|
        expect(entity['type']).to eq 'object'
        entity['oneOf'].tap do |one_of|
          expect(one_of[0]['required']).to eq ['name', 'age']
          expect(one_of[0]['properties']['name']['type']).to eq 'string'
          expect(one_of[1]['required']).to eq ['name', 'reg_code']
        end
      end
    end
    expect(result['required']).to eq ['name', 'age', 'entity_type']
  end
end
