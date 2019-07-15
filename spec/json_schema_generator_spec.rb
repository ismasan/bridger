require 'spec_helper'
require 'bridger/json_schema_generator'

RSpec.describe Bridger::JsonSchemaGenerator do
  let(:s1) do
    Parametric::Schema.new do
      field(:name).type(:string).present
      field(:age).type(:integer).required.default(41)
      field(:options).type(:string).options(['A', 'B'])
      field(:friends).type(:array).schema do
        field(:name).type(:string).present
      end
      field(:company).type(:object).schema do
        field(:name).type(:string).present
      end
    end
  end

  it 'serializes structure correctly' do
    result = described_class.generate(s1)
    expect(result['$schema']).to eq 'http://json-schema.org/draft-04/schema#'
    expect(result['type']).to eq 'object'
    result['properties'].tap do |props|
      expect(props['name']['type']).to eq 'string'
      expect(props['age']['type']).to eq 'integer'
      expect(props['age']['default']).to eq 41
      expect(props['options']['type']).to eq 'string'
      expect(props['options']['enum']).to eq ['A', 'B']
      expect(props['company']['type']).to eq 'object'
      props['company']['properties'].tap do |company|
        expect(company['name']['type']).to eq 'string'
      end
      expect(props['company']['required']).to eq ['name']

      expect(props['friends']['type']).to eq 'array'
    end
    expect(result['required']).to eq ['name', 'age']
  end
end
