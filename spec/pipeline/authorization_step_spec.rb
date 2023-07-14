# frozen_string_literal: true

require "spec_helper"
require 'bridger/pipeline/authorization_step'
require 'bridger/result'

RSpec.describe Bridger::Pipeline::AuthorizationStep do
  subject(:step) do
    described_class.new(auth_config, scope('a.b'))
  end

  let(:auth_config) do
    Bridger::Auth::Config.new.tap do |c|
      c.authenticator do |request|
        request.env['API_TOKEN']
      end
      c.token_store = {
        'admin' => { 'scopes' => ['a'] },
        'public' => { 'scopes' => ['a.b.c'] },
      }
    end
  end

  context 'with unauthorized request' do
    specify 'no access token' do
      initial = result_with_token(nil)
      result = step.call(initial)
      expect(result.response.status).to eq(401)
      expect(result.halted?).to be(true)
    end

    specify 'unknown access token' do
      initial = result_with_token('nope')
      result = step.call(initial)
      expect(result.response.status).to eq(401)
      expect(result.halted?).to be(true)
    end
  end

  specify 'unauthenticated request' do
    initial = result_with_token('public')
    result = step.call(initial)
    expect(result.response.status).to eq(403)
    expect(result.halted?).to be(true)
  end

  specify 'malformed access token' do
    allow(auth_config.token_store).to receive(:get).and_raise(Bridger::InvalidAccessTokenError)

    initial = result_with_token('foo')
    result = step.call(initial)
    expect(result.response.status).to eq(401)
    expect(result.halted?).to be(true)
  end

  specify 'expired access token' do
    allow(auth_config.token_store).to receive(:get).and_raise(Bridger::ExpiredAccessTokenError)

    initial = result_with_token('foo')
    result = step.call(initial)
    expect(result.response.status).to eq(401)
    expect(result.halted?).to be(true)
  end

  specify 'authenticated request' do
    initial = result_with_token('admin')
    result = step.call(initial)
    expect(result.response.status).to eq(200)
    expect(result.halted?).to be(false)
  end

  private

  def result_with_token(token)
    Bridger::Result::Success.build(
      request: request_with_token(token),
    )
  end

  def request_with_token(token)
    env = {
      input: StringIO.new('{"foo":"bar"}'),
    }
    env['API_TOKEN'] = token if token

    Rack::Request.new(Rack::MockRequest.env_for('/', env))
  end

  def scope(str)
    Bridger::Scopes::Scope.wrap(str)
  end
end
