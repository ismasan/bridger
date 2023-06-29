# frozen_string_literal: true

require 'rack'
require 'spec_helper'
require 'bridger/result'

RSpec.describe Bridger::Result do
  let(:request) do
    env = Rack::MockRequest.env_for('/foo')
    Rack::Request.new(env)
  end
  let(:response) do
    Rack::Response.new(nil, 200, {})
  end

  describe Bridger::Result::Success do
    subject(:result) { described_class.new(request, response) }

    specify '.build' do
      result = described_class.build
      expect(result.request).to be_a Rack::Request
      expect(result.response).to be_a Rack::Response

      result = described_class.build(request: request, response: response)
      expect(result.request).to eq request
      expect(result.response).to eq response
    end

    specify '#halted? is false' do
      expect(result.halted?).to be false
    end

    specify '#halt' do
      result.response.status = 201
      halted = result.halt
      expect(halted).to be_a Bridger::Result::Halt
      expect(halted.response.status).to eq 201

      halted = result.halt do |r|
        r.response.status = 202
        r[:foo] = 'bar'
      end
      expect(result.response.status).to eq 201
      expect(halted.response.status).to eq 202
      expect(halted[:foo]).to eq 'bar'
      expect(halted.data[:foo]).to eq 'bar'
      expect(halted[:bar]).to be_nil
      expect(halted).to be_a Bridger::Result::Halt

      halted = result.halt(errors: { foo: 'bar' })
      expect(halted.response.status).to eq 201
      expect(halted).to be_a Bridger::Result::Halt
      expect(halted.valid?).to be false
      expect(halted.errors[:foo]).to eq 'bar'
    end

    specify '#continue' do
      result.response.status = 201
      continued = result.continue
      expect(continued).not_to eq result

      continued = result.continue do |r|
        r.response.status = 202
        r[:foo] = 'bar'
      end
      expect(result.response.status).to eq 201
      expect(continued.response.status).to eq 202
      expect(continued[:foo]).to eq 'bar'
      expect(continued).not_to eq result

      continued = result.continue(errors: { foo: 'bar' })
      expect(continued.response.status).to eq 201
      expect(continued).not_to eq result
      expect(continued.valid?).to be false
      expect(continued.errors[:foo]).to eq 'bar'
    end

    specify '#valid?' do
      expect(result.valid?).to be true
      result.errors[:foo] = 'bar'
      expect(result.valid?).to be false
    end
  end

  describe Bridger::Result::Halt do
    subject(:result) { described_class.new(request, response) }

    specify '#halted? is true' do
      expect(result.halted?).to be true
    end

    specify '#halt' do
      result.response.status = 201
      halted = result.halt
      expect(halted).not_to eq result

      halted = result.halt do |r|
        r.response.status = 202
      end
      expect(result.response.status).to eq 201
      expect(halted.response.status).to eq 202
      expect(halted).not_to eq result

      halted = result.halt(errors: { foo: 'bar' })
      expect(halted.response.status).to eq 201
      expect(halted).not_to eq result
      expect(halted.valid?).to be false
      expect(halted.errors[:foo]).to eq 'bar'
    end

    specify '#continue' do
      result.response.status = 201
      continued = result.continue
      expect(continued).to be_a Bridger::Result::Success
      expect(continued.response.status).to eq 201

      continued = result.continue do |r|
        r.response.status = 202
      end
      expect(result.response.status).to eq 201
      expect(continued.response.status).to eq 202
      expect(continued).to be_a Bridger::Result::Success
    end
  end
end
