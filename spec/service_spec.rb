# frozen_string_literal: true

require "spec_helper"
require "bridger/service"

RSpec.describe Bridger::Service do
  Action = Class.new do
    def initialize(result)
      @result = result
    end

    def call(query: {}, payload: {}, auth:)
      @result
    end
  end

  Serializer = Class.new do
    def self.call(data, h:, auth:)
      data
    end
  end

  it "registers endpoints" do
    auth = double('Auth', authorize!: true, shop_ids: [1,2,3])

    points = described_class.new.build do
      authorize "btc.account.shops.mine" do |scope, auth, params|
        auth.shop_ids.include? params[:shop_id].to_i
      end

      endpoint(:root, :get, "/?",
        title: "API root",
        scope: "btc.me",
        action: Action.new(foo: 'bar'),
        serializer: Serializer
      )

      endpoint(:shop, :get, "/shops/:id",
        title: "Shop details",
        scope: "btc.account.shops.mine.list",
        action: Action.new(bar: 'foo'),
        serializer: Serializer
      )
    end

    # it looks up
    endpoint = points[:root]
    expect(endpoint).to be_a Bridger::Endpoint
    expect(endpoint.path).to eq '/?'
    expect(endpoint.verb).to eq :get

    helper = double('Helper', params: {shop_id: 2})
    result = endpoint.run!(payload: {}, auth: auth, helper: helper)
    expect(result.to_hash).to eq(foo: 'bar')
  end

  it 'passes instrumenter to endpoints' do
    instrumenter = double('SomeInstrumenter', instrument: {})
    expect(Bridger::Endpoint).to receive(:new).with(hash_including(instrumenter: instrumenter)).and_call_original

    srv = described_class.new
    srv.instrumenter instrumenter
    srv.endpoint(:shop, :get, '/shops/:id',
      title: "API root",
      scope: "btc.me",
      action: Action.new(foo: 'bar'),
      serializer: Serializer
    )
  end

  it 'checks that instrumenter implements #instrument' do
    srv = described_class.new

    expect {
      srv.instrumenter 'nope!'
    }.to raise_error(ArgumentError)
  end

  it 'has #auth_config pointing to global Bridger::Auth.config by default' do
    srv = described_class.new
    expect(srv.auth_config).not_to be_nil
    expect(srv.auth_config).to eq(Bridger::Auth.config)
  end

  describe '#authenticate' do
    it 'sets #auth_config with new config object' do
      authenticator = ->(_req) { 'abc' }

      srv = described_class.new
      srv.authenticate do |c|
        c.authenticator authenticator
      end

      expect(srv.auth_config).not_to eq(Bridger::Auth.config)
      expect(srv.auth_config.authenticator.call(nil)).to eq('abc')
    end
  end
end
