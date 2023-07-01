# frozen_string_literal: true

require "spec_helper"
require "bridger/endpoint2"

RSpec.describe Bridger::Endpoint2 do
  subject(:endpoint) do
    Bridger::Endpoint2.new(:update_task, service: service) do |e|
      e.path '/tasks/:id'
      e.verb :put
      e.title 'Update Task'
      e.scope 'a.b.c'

      e.instrumenter instrumenter

      e.auth do |c|
        c.authenticator do |request|
          request.env['API_TOKEN']
        end
        c.token_store = {
          'admin_token' => { 'scopes' => %w[a.b] },
        }
      end

      e.action do |pl|
        pl.query_schema do
          field(:id).type(:integer).present
        end
        pl.payload_schema do
          field(:title).type(:string).present
        end
        pl.instrument('test.action') do |pl|
          pl.step do |r|
            r.continue(object: 'New task!')
          end
        end
      end

      e.serializer do |r|
        r.on(200, success_serializer)
      end
    end
  end

  let(:instrumenter) do
    Bridger::TestInstrumenter.new
  end

  let(:success_serializer) do
    proc do |result, auth:, h:|
      { message: "the result is #{result.object}" }
    end
  end

  let(:service) { nil }

  specify 'readers' do
    expect(endpoint.name).to eq(:update_task)
    expect(endpoint.path).to eq('/tasks/:id')
    expect(endpoint.verb).to eq(:put)
    expect(endpoint.title).to eq('Update Task')
    expect(endpoint.scope.to_s).to eq('a.b.c')
  end

  specify '#query_schema' do
    expect(endpoint.query_schema).to be_a(Parametric::Schema)
    expect(endpoint.query_schema.fields.keys).to eq(%i[id])
  end

  specify '#payload_schema' do
    expect(endpoint.payload_schema).to be_a(Parametric::Schema)
    expect(endpoint.payload_schema.fields.keys).to eq(%i[title])
  end

  specify 'successful results' do
    response = run_endpoint(
      endpoint,
      'https://api.company.io/things/1?search=ruby',
      'action_dispatch.request.path_parameters' => { id: 1 },
      'API_TOKEN' => 'admin_token',
      'CONTENT_TYPE' => 'application/json',
      method: 'POST',
      input: StringIO.new('{"title":"foo"}'),
    )

    expect(response[0]).to eq(200)
    expect(response[1]['Content-Type']).to eq('application/json')

    json_data(response).tap do |data|
      expect(data[:message]).to eq('the result is New task!')
    end

    expect(instrumenter.calls).to eq([
      ['bridger.endpoint', { name: :update_task, path: '/tasks/:id', scope: 'a.b.c', verb: :put }],
      ['bridger.endpoint.parse_payload', {}],
      ['bridger.endpoint.validate_inputs', {}],
      ['bridger.endpoint.action', { info: '#<Bridger::Pipeline>' }],
      ['test.action', {}],
      ['bridger.endpoint.serializer', {}],
    ])
  end

  specify 'invalid or halted results' do
    response = run_endpoint(
      endpoint,
      'https://api.company.io/things/1?search=ruby',
      'action_dispatch.request.path_parameters' => { id: 1 },
      'API_TOKEN' => 'admin_token',
      method: 'POST',
      input: StringIO.new('{}'),
    )

    expect(response[0]).to eq(422)
    expect(response[1]['Content-Type']).to eq('application/json')
    json_data(response).tap do |data|
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('$.title')
        expect(err[:messages]).to eq(['is required'])
      end
    end
  end

  context 'with custom action objects' do
    subject(:endpoint) do
      Bridger::Endpoint2.new(:update_task, service: service) do |e|
        e.path '/tasks/:id'
        e.verb :put
        e.title 'Update Task'

        e.action custom_action

        # .. or
        # e.action Tasks::Actions::Update.new

        e.serializer do |r|
          r.on(200, success_serializer)
        end
      end
    end

    let(:custom_action) do
      Class.new do
        def self.query_schema
          Parametric::Schema.new do
            field(:id).type(:integer).present
          end
        end

        def self.payload_schema
          Parametric::Schema.new do
            field(:title).type(:string).present
          end
        end

        def self.call(result)
          result.continue(object: 'hello!')
        end
      end
    end

    specify '#query_schema' do
      expect(endpoint.query_schema).to be_a(Parametric::Schema)
      expect(endpoint.query_schema.fields.keys).to eq(%i[id])
    end

    specify '#payload_schema' do
      expect(endpoint.payload_schema).to be_a(Parametric::Schema)
      expect(endpoint.payload_schema.fields.keys).to eq(%i[title])
    end

    specify 'successful results' do
      response = run_endpoint(
        endpoint,
        'https://api.company.io/things/1?search=ruby',
        'action_dispatch.request.path_parameters' => { id: 1 },
        'CONTENT_TYPE' => 'application/json',
        method: 'POST',
        input: StringIO.new('{"title":"foo"}'),
      )

      expect(response[0]).to eq(200)
      expect(response[1]['Content-Type']).to eq('application/json')

      json_data(response).tap do |data|
        expect(data[:message]).to eq('the result is hello!')
      end
    end

    specify 'invalid results' do
      response = run_endpoint(
        endpoint,
        'https://api.company.io/things/1?search=ruby',
        'action_dispatch.request.path_parameters' => { id: 1 },
        'CONTENT_TYPE' => 'application/json',
        method: 'POST',
        input: StringIO.new('{}'),
      )

      expect(response[0]).to eq(422)
      expect(response[1]['Content-Type']).to eq('application/json')

      json_data(response).tap do |data|
        data.dig(:_embedded, :errors)[0].tap do |err|
          expect(err[:field]).to eq('$.title')
          expect(err[:messages]).to eq(['is required'])
        end
      end
    end
  end

  private

  def run_endpoint(endpoint, url, env = {})
    env = Rack::MockRequest.env_for(url, env)
    endpoint.to_rack.call(env)
  end

  def json_data(response)
    JSON.parse(response[2].first, symbolize_names: true)
  end
end
