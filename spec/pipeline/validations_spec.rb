# frozen_string_literal: true

require "spec_helper"
require 'bridger/result'
require 'bridger/pipeline/validations'

RSpec.describe Bridger::Pipeline::Validations do
  describe Bridger::Pipeline::Validations::Query do
    specify 'validating' do
      schema = Parametric::Schema.new do
        field(:id).type(:integer).present
      end

      step = described_class.new(schema)

      result = step.call(Bridger::Result::Success.build(query: {}))
      expect(result.response.status).to eq(422)
      expect(result.errors['$.id']).to eq(['is required'])

      result = step.call(Bridger::Result::Success.build(query: { id: 12 }))
      expect(result.response.status).to eq(200)
      expect(result.errors.any?).to eq(false)
    end
  end

  describe Bridger::Pipeline::Validations::Payload do
    specify 'validating' do
      schema = Parametric::Schema.new do
        field(:id).type(:integer).present
      end

      step = described_class.new(schema)

      result = step.call(Bridger::Result::Success.build(payload: {}))
      expect(result.response.status).to eq(422)
      expect(result.errors['$.id']).to eq(['is required'])

      result = step.call(Bridger::Result::Success.build(payload: { id: 12 }))
      expect(result.response.status).to eq(200)
      expect(result.errors.any?).to eq(false)
    end
  end
end
