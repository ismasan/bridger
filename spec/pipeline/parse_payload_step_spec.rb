# frozen_string_literal: true

require "spec_helper"
require 'bridger/pipeline/parse_payload_step'
require 'bridger/result'

RSpec.describe Bridger::Pipeline::ParsePayloadStep do
  let(:initial_result) do
    Bridger::Result::Success.build(request:)
  end
  let(:request) do
    env = Rack::MockRequest.env_for(
      '/',
      input: StringIO.new('{"foo":"bar"}'),
    )
    Rack::Request.new(env)
  end

  specify do
    result = described_class.new.call(initial_result)
    expect(result.payload).to eq({ foo: 'bar' })
  end
end
