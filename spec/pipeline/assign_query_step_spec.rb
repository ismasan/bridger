# frozen_string_literal: true

require "spec_helper"
require 'bridger/pipeline/assign_query_step'
require 'bridger/result'

RSpec.describe Bridger::Pipeline::AssignQueryStep do
  let(:initial_result) do
    Bridger::Result::Success.build(request:)
  end
  let(:request) do
    env = Rack::MockRequest.env_for(
      '/?search=foo&product[price]=100&product[category]=bar',
      method: 'GET',
    )
    Rack::Request.new(env)
  end

  context 'with Rack request' do
    specify  do
      result = described_class.call(initial_result)
      expect(result.query[:search]).to eq('foo')
      expect(result.query[:product][:price]).to eq('100')
      expect(result.query[:product][:category]).to eq('bar')
    end
  end

  context 'with Rails path parameters' do
    let(:request) do
      env = Rack::MockRequest.env_for(
        '/?product[price]=100&product[category]=bar',
        'action_dispatch.request.path_parameters' => {
          'search' => 'foo',
        },
        method: 'GET',
      )
      Rack::Request.new(env)
    end

    specify  do
      result = described_class.call(initial_result)
      expect(result.query[:search]).to eq('foo')
      expect(result.query[:product][:price]).to eq('100')
      expect(result.query[:product][:category]).to eq('bar')
    end
  end
end
