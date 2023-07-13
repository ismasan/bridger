# frozen_string_literal: true

require "spec_helper"
require "bridger/service"

RSpec.describe Bridger::Service do
  Action = Class.new do
    def initialize(data = {})
      @data = data
    end

    def call(result)
      result.continue(@data)
    end
  end

  Serializer = Class.new do
    def self.call(data, h:, auth:)
      data
    end
  end

  it "registers endpoints" do
    points = described_class.new.build do
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
    expect(endpoint.path).to eq '/?'
    expect(endpoint.verb).to eq :get
  end

  it 'passes instrumenter to endpoints' do
    instrumenter = double('SomeInstrumenter', instrument: {})

    srv = described_class.new
    srv.instrumenter instrumenter
    srv.endpoint(:shop, :get, '/shops/:id',
      title: "API root",
      scope: "btc.me",
      action: Action.new(foo: 'bar'),
      serializer: Serializer
    )
    ep = srv[:shop]
    expect(ep.instrumenter).to eq instrumenter
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
